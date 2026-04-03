import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/settings/citizen_preferences_scope.dart';
import '../../core/settings/citizen_strings.dart';
import 'alert_severity_palette.dart';
import 'alerts_api.dart';
import 'alerts_cache.dart';
import 'citizen_alert.dart';

class AlertsScreen extends StatefulWidget {
  final CitizenAlertsApi? api;
  final CitizenAlertsCache? cache;

  const AlertsScreen({super.key, this.api, this.cache});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final CitizenAlertsApi _api;
  late final CitizenAlertsCache _cache;
  static const Duration _autoRefreshInterval = Duration(seconds: 20);
  Timer? _autoRefreshTimer;
  bool _loading = true;
  bool _usingCachedAlerts = false;
  String? _errorMessage;
  List<CitizenAlert> _alerts = <CitizenAlert>[];
  DateTime? _lastUpdatedAt;
  bool _isAutoRefreshing = false;

  String _languageCode(BuildContext context) {
    return CitizenPreferencesScope.maybeOf(context)?.languageCode ?? 'en';
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpCitizenAlertsApi();
    _cache = widget.cache ?? SharedPrefsCitizenAlertsCache();
    _loadAlerts();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (Timer _) {
      _autoRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  bool _isDataSaverEnabled() {
    return CitizenPreferencesScope.maybeOf(context)?.dataSaverEnabled ?? false;
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _usingCachedAlerts = false;
    });

    try {
      final List<CitizenAlert> alerts = await _api.fetchAlerts();
      await _cache.saveAlerts(alerts);
      final DateTime? updatedAt = await _cache.lastUpdatedAt();
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _usingCachedAlerts = false;
        _lastUpdatedAt = updatedAt;
      });
    } catch (e) {
      debugPrint('Alerts fetch failed (${_api.runtimeType}): $e');
      final List<CitizenAlert> cached = await _cache.loadAlerts();
      final DateTime? updatedAt = await _cache.lastUpdatedAt();
      if (!mounted) return;
      if (cached.isNotEmpty) {
        setState(() {
          _alerts = cached;
          _usingCachedAlerts = true;
          _errorMessage = null;
          _lastUpdatedAt = updatedAt;
        });
      } else {
        final String languageCode = _languageCode(context);
        setState(
          () => _errorMessage = CitizenStrings.tr(
            'alerts_load_failed',
            languageCode,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _updatedAgo(DateTime? timestamp, String languageCode) {
    if (timestamp == null) {
      return CitizenStrings.tr('time_unknown', languageCode);
    }
    return CitizenStrings.relativeTimeFromNow(
      timestamp.toLocal(),
      languageCode,
    );
  }

  Future<void> _autoRefresh() async {
    if (!mounted || _loading || _isAutoRefreshing) return;
    if (_isDataSaverEnabled()) return;
    _isAutoRefreshing = true;
    try {
      await _loadAlerts();
    } finally {
      _isAutoRefreshing = false;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity.toUpperCase()) {
      case 'EMERGENCY':
        return Icons.crisis_alert_rounded;
      case 'ALERT':
        return Icons.warning_rounded;
      case 'WARNING':
        return Icons.report_problem_rounded;
      case 'WATCH':
        return Icons.visibility_rounded;
      case 'ADVISORY':
        return Icons.info_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String languageCode = _languageCode(context);
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (_loading && _alerts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _alerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: colors.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('alerts-retry-button'),
                onPressed: _loadAlerts,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(CitizenStrings.tr('retry', languageCode)),
              ),
              const SizedBox(height: 16),
              Tooltip(
                message: CitizenStrings.tr('alerts_step_check_connection', languageCode) +
                    '\n' +
                    CitizenStrings.tr('alerts_step_open_safezones', languageCode) +
                    '\n' +
                    CitizenStrings.tr('alerts_step_call_helpline', languageCode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.help_outline_rounded, size: 16, color: colors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        CitizenStrings.tr('alerts_next_steps_title', languageCode),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_alerts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAlerts,
        child: ListView(
          children: <Widget>[
            const SizedBox(height: 80),
            Center(
              child: Column(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F855A).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 56,
                      color: Color(0xFF2F855A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    CitizenStrings.tr('alerts_empty', languageCode),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: <Widget>[
          // Offline banner
          if (_usingCachedAlerts)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFB7791F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.cloud_off_rounded, size: 20, color: Color(0xFFB7791F)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      CitizenStrings.tr('alerts_offline_banner', languageCode),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (_usingCachedAlerts) const SizedBox(height: 12),

          // Header row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF57C00).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, size: 28, color: Color(0xFFF57C00)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _alerts.length.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                      ),
                      Text(
                        CitizenStrings.tr('alerts_feed_title', languageCode),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    IconButton(
                      key: const Key('alerts-refresh-button'),
                      onPressed: _loading ? null : _loadAlerts,
                      icon: const Icon(Icons.refresh_rounded),
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      _updatedAgo(_lastUpdatedAt, languageCode),
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Alert cards
          ..._alerts.map((CitizenAlert alert) {
            final Color badgeColor = citizenAlertSeverityColor(alert.severity);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.18)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _severityIcon(alert.severity),
                          size: 22,
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    alert.severity,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _updatedAgo(alert.timestamp, languageCode),
                                  style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              alert.message,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
