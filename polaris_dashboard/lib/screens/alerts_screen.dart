import 'dart:async';
import 'package:flutter/material.dart';
import 'package:polaris_dashboard/core/global_reload.dart';
import 'package:provider/provider.dart';

import '../core/api_service.dart';
import '../core/models/alert_event.dart';
import '../core/theme_utils.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertEvent> alerts = [];
  bool loading = true;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    loadAlerts();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => loadAlerts(),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadAlerts() async {
    try {
      final data = await ApiService.fetchAlertHistory();
      setState(() {
        alerts = data.reversed.toList(); // latest on top
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<GlobalReload>();
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (alerts.isEmpty) {
      return const Center(
        child: Text("No alerts dispatched yet."),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: alerts.length,
      itemBuilder: (_, i) {
        final a = alerts[i];
        return _alertCard(a);
      },
    );
  }

  Widget _alertCard(AlertEvent a) {
    final color = severityColor(a.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 5),
        ),
        color: Colors.white,
      ),
      child: ListTile(
        title: Text(
          a.severity,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(a.message),
            const SizedBox(height: 6),
            Text(
              "${a.channel} • ${a.timestamp.toLocal()}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
