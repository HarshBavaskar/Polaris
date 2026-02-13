import 'dart:async';

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

    return RefreshIndicator(
      onRefresh: loadAlerts,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Alerts Feed',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
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
            child: Wrap(
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
                child: _alertCard(filtered[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _alertCard(AlertEvent alert) {
    final color = severityColor(alert.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        alert.severity,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(alert.channel),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(alert.message),
                  const SizedBox(height: 8),
                  Text(
                    alert.timestamp.toLocal().toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
