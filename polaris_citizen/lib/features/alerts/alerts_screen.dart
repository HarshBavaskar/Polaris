import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/settings/citizen_preferences_scope.dart';
import '../../core/settings/citizen_strings.dart';
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

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'EMERGENCY':
        return const Color(0xFFB71C1C);
      case 'ALERT':
        return const Color(0xFFDD6B20);
      case 'WARNING':
        return const Color(0xFFB7791F);
      case 'WATCH':
      case 'ADVISORY':
        return const Color(0xFF2B6CB0);
      default:
        return const Color(0xFF4A5568);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String languageCode = _languageCode(context);
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
              Text(_errorMessage!),
              const SizedBox(height: 8),
              Text(
                CitizenStrings.tr('alerts_next_steps_title', languageCode),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                CitizenStrings.tr('alerts_step_check_connection', languageCode),
              ),
              const SizedBox(height: 2),
              Text(
                CitizenStrings.tr('alerts_step_open_safezones', languageCode),
              ),
              const SizedBox(height: 2),
              Text(
                CitizenStrings.tr('alerts_step_call_helpline', languageCode),
              ),
              const SizedBox(height: 10),
              FilledButton(
                key: const Key('alerts-retry-button'),
                onPressed: _loadAlerts,
                child: Text(CitizenStrings.tr('retry', languageCode)),
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
            SizedBox(height: 140),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(CitizenStrings.tr('alerts_empty', languageCode)),
                      const SizedBox(height: 8),
                      Text(
                        CitizenStrings.tr(
                          'alerts_next_steps_title',
                          languageCode,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CitizenStrings.tr(
                          'alerts_step_check_connection',
                          languageCode,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CitizenStrings.tr(
                          'alerts_step_open_safezones',
                          languageCode,
                        ),
                      ),
                    ],
                  ),
                ),
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
          if (_usingCachedAlerts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  CitizenStrings.tr('alerts_offline_banner', languageCode),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (_usingCachedAlerts) const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(
                CitizenStrings.tr('alerts_feed_title', languageCode),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${CitizenStrings.trf('alerts_count', languageCode, <String, String>{'count': _alerts.length.toString()})}\n'
                '${CitizenStrings.trf('alerts_last_synced', languageCode, <String, String>{'ago': _updatedAgo(_lastUpdatedAt, languageCode)})}',
              ),
              trailing: IconButton(
                key: const Key('alerts-refresh-button'),
                onPressed: _loading ? null : _loadAlerts,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._alerts.map((CitizenAlert alert) {
            final Color badgeColor = _severityColor(alert.severity);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: badgeColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              alert.severity,
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            CitizenStrings.trf(
                              'alerts_updated',
                              languageCode,
                              <String, String>{
                                'ago': _updatedAgo(
                                  alert.timestamp,
                                  languageCode,
                                ),
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(alert.message),
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
