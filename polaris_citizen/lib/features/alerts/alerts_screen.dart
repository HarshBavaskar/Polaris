import 'package:flutter/material.dart';
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
  bool _loading = true;
  bool _usingCachedAlerts = false;
  String? _errorMessage;
  List<CitizenAlert> _alerts = <CitizenAlert>[];

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpCitizenAlertsApi();
    _cache = widget.cache ?? SharedPrefsCitizenAlertsCache();
    _loadAlerts();
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
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _usingCachedAlerts = false;
      });
    } catch (_) {
      final List<CitizenAlert> cached = await _cache.loadAlerts();
      if (!mounted) return;
      if (cached.isNotEmpty) {
        setState(() {
          _alerts = cached;
          _usingCachedAlerts = true;
          _errorMessage = null;
        });
      } else {
        setState(() => _errorMessage = 'Failed to load alerts.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _updatedAgo(DateTime timestamp) {
    final Duration diff = DateTime.now().difference(timestamp);
    if (diff.isNegative || diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
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
              FilledButton(
                key: const Key('alerts-retry-button'),
                onPressed: _loadAlerts,
                child: const Text('Retry'),
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
          children: const <Widget>[
            SizedBox(height: 140),
            Center(child: Text('No alerts available right now.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: <Widget>[
          if (_usingCachedAlerts)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Offline mode: showing last saved alerts.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Card(
            child: ListTile(
              title: const Text(
                'Alerts Feed',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${_alerts.length} alert(s)'),
              trailing: IconButton(
                key: const Key('alerts-refresh-button'),
                onPressed: _loading ? null : _loadAlerts,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._alerts.map((CitizenAlert alert) {
            final Color badgeColor = _severityColor(alert.severity);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                        Text('Updated ${_updatedAgo(alert.timestamp)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(alert.message),
                    const SizedBox(height: 8),
                    Text(
                      'Channel: ${alert.channel}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
