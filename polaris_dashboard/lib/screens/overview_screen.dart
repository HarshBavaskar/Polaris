import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Timer? _cameraTimer;
  Timer? _decisionTimer;

  String _frameUrl = "";
  Map<String, dynamic>? decision;

  final String baseUrl = "http://localhost:8000";
  final String cameraEndpoint = "http://localhost:8000/camera/latest-frame";

  @override
  void initState() {
    super.initState();
    _refreshFrame();
    _fetchDecision();

    _cameraTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _refreshFrame());

    _decisionTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _fetchDecision());
  }

  @override
  void dispose() {
    _cameraTimer?.cancel();
    _decisionTimer?.cancel();
    super.dispose();
  }

  void _refreshFrame() {
    setState(() {
      _frameUrl =
          "$cameraEndpoint?ts=${DateTime.now().millisecondsSinceEpoch}";
    });
  }

  Future<void> _fetchDecision() async {
    try {
      final res =
          await http.get(Uri.parse("$baseUrl/decision/latest"));

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      if (data.isEmpty) return;

      setState(() {
        decision = data;
      });
    } catch (_) {}
  }

  Color _riskColor(String? risk) {
    switch (risk) {
      case "IMMINENT":
        return Colors.red;
      case "WARNING":
        return Colors.orange;
      case "WATCH":
        return Colors.yellow.shade700;
      default:
        return Colors.green;
    }
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case "EMERGENCY":
        return Colors.red;
      case "ALERT":
        return Colors.orange;
      case "ADVISORY":
        return Colors.yellow.shade700;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= HEADER =================
          const Text(
            "Authority Overview",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // ================= CAMERA + STATUS =================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LIVE CAMERA
              Expanded(
                flex: 2,
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          "Live Camera Feed",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _frameUrl.isEmpty
                            ? const Center(
                                child: CircularProgressIndicator(),
                              )
                            : Image.network(
                                _frameUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text(
                                    "Camera feed unavailable",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // STATUS CARDS (LIVE DATA)
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _StatusCard(
                      title: "Current Risk",
                      value: decision?["final_risk_level"] ?? "—",
                      color: _riskColor(
                          decision?["final_risk_level"]),
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      title: "Alert Severity",
                      value:
                          decision?["final_alert_severity"] ?? "—",
                      color: _severityColor(
                          decision?["final_alert_severity"]),
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      title: "Decision Mode",
                      value: decision?["decision_mode"] ?? "—",
                      color: decision?["decision_mode"] ==
                              "MANUAL_OVERRIDE"
                          ? Colors.red
                          : Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      title: "ETA",
                      value: decision?["final_eta"] ?? "—",
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================= STATUS CARD =================

class _StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatusCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
