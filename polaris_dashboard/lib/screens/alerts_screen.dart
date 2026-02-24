import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api_service.dart';
import '../core/refresh_config.dart';
import '../core/models/alert_event.dart';
import '../core/theme_utils.dart';
import '../widgets/animated_reveal.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const List<String> _severityOrder = [
    'ALL',
    'EMERGENCY',
    'ALERT',
    'WARNING',
    'WATCH',
    'ADVISORY',
    'INFO',
  ];

  List<AlertEvent> alerts = [];
  bool loading = true;
  Timer? refreshTimer;
  bool _isRefreshing = false;
  String selectedSeverity = 'ALL';

  @override
  void initState() {
    super.initState();
    loadAlerts();
    refreshTimer = Timer.periodic(RefreshConfig.alertsPoll, (_) => loadAlerts());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadAlerts() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final data = await ApiService.fetchAlertHistory(
        limit: selectedSeverity == 'ALL' ? 200 : 500,
        severity: selectedSeverity == 'ALL' ? null : selectedSeverity,
      );
      data.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!mounted) return;
      setState(() {
        alerts = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final severities = <String>{
      ..._severityOrder,
      ...alerts.map((a) => a.severity.toUpperCase()),
    }.toList();

    severities.sort((a, b) {
      final ai = _severityOrder.indexOf(a);
      final bi = _severityOrder.indexOf(b);
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;
      return a.compareTo(b);
    });

    final filtered = alerts;

    final compact = MediaQuery.sizeOf(context).width < 900 || isAndroidUi;

    return RefreshIndicator(
      onRefresh: loadAlerts,
      child: ListView(
        padding: EdgeInsets.all(compact ? 12 : 24),
        children: [
        Text(
          'Alerts Feed',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        const SizedBox(height: 6),
        Text(
          compact
              ? 'Focused incident list'
              : 'Focused incident list with severity filters',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '${filtered.length} alerts visible',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          AnimatedReveal(
            delay: const Duration(milliseconds: 40),
            child: compact
                ? DropdownButtonFormField<String>(
                    initialValue: selectedSeverity,
                    decoration: const InputDecoration(
                      labelText: 'Severity Filter',
                      border: OutlineInputBorder(),
                    ),
                    items: severities
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null || value == selectedSeverity) return;
                      setState(() {
                        selectedSeverity = value;
                        loading = true;
                      });
                      await loadAlerts();
                    },
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: severities
                        .map(
                          (s) => ChoiceChip(
                            label: Text(s),
                            selected: selectedSeverity == s,
                            onSelected: (_) async {
                              if (selectedSeverity == s) return;
                              setState(() {
                                selectedSeverity = s;
                                loading = true;
                              });
                              await loadAlerts();
                            },
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 18),
          if (filtered.isEmpty)
            AnimatedReveal(
              delay: const Duration(milliseconds: 90),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No alerts dispatched yet.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            )
          else
            ...List.generate(
              filtered.length,
              (index) => AnimatedReveal(
                delay: Duration(milliseconds: 90 + (index * 40)),
                child: _alertCard(filtered[index], compact: compact),
              ),
            ),
        ],
      ),
    );
  }

  Widget _alertCard(AlertEvent alert, {required bool compact}) {
    final color = severityColor(alert.severity);
    final ts = alert.timestamp.toLocal();
    final timestamp =
        '${ts.year.toString().padLeft(4, '0')}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} '
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    alert.severity,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.message,
              maxLines: compact ? 3 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: color),
                  const SizedBox(width: 6),
                  Text(
                    'Severity: ${alert.severity}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
