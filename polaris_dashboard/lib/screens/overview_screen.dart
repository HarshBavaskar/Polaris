import 'package:flutter/material.dart';
import 'package:polaris_dashboard/core/global_reload.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/models/decision.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Decision? decision;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadDecision();
  }

  Future<void> loadDecision() async {
    try {
      final d = await ApiService.fetchLatestDecision();
      setState(() {
        decision = d;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<GlobalReload>();
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(child: Text("Error: $error"));
    }

    final d = decision!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Current System Decision",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row("Risk Level", d.riskLevel),
                  _row("Alert Severity", d.alertSeverity),
                  _row("ETA", "${d.eta} (${d.etaConfidence})"),
                  _row(
                    "Overall Confidence",
                    "${(d.confidence * 100).toStringAsFixed(0)}%",
                  ),
                  const Divider(height: 24),
                  const Text(
                    "Decision Justification",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d.justification,
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
