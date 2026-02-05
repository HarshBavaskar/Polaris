import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  Timer? _refreshTimer;

  List<double> riskSeries = [];
  List<double> confidenceSeries = [];
  Map<String, int> severityCounts = {};

  bool loading = true;

  final String baseUrl = "http://localhost:8000";

  @override
  void initState() {
    super.initState();
    _loadAll();

    _refreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _loadAll());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadRiskTrend(),
      _loadConfidenceTrend(),
      _loadAlertDistribution(),
    ]);

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _loadRiskTrend() async {
    try {
      final res =
          await http.get(Uri.parse("$baseUrl/dashboard/risk-timeseries"));
      if (res.statusCode != 200) return;

      final List data = jsonDecode(res.body);
      riskSeries =
          data.map<double>((e) => (e["risk_score"] ?? 0).toDouble()).toList();
    } catch (_) {}
  }

  Future<void> _loadConfidenceTrend() async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/dashboard/confidence-timeseries"));
      if (res.statusCode != 200) return;

      final List data = jsonDecode(res.body);
      confidenceSeries =
          data.map<double>((e) => (e["confidence"] ?? 0).toDouble()).toList();
    } catch (_) {}
  }

  Future<void> _loadAlertDistribution() async {
    try {
      final res =
          await http.get(Uri.parse("$baseUrl/alerts/history"));
      if (res.statusCode != 200) return;

      final List alerts = jsonDecode(res.body);
      severityCounts.clear();

      for (final a in alerts) {
        final sev = a["severity"] ?? "UNKNOWN";
        severityCounts[sev] = (severityCounts[sev] ?? 0) + 1;
      }
    } catch (_) {}
  }

  Widget _sparkline(List<double> data, Color color) {
    if (data.isEmpty) {
      return const Text("No data available");
    }

    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _SparklinePainter(data, color),
        size: Size.infinite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "System Trends",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          if (loading)
            const Center(child: CircularProgressIndicator()),

          if (!loading) ...[
            // RISK TREND
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Risk Score Trend",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _sparkline(riskSeries, Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CONFIDENCE TREND
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Confidence Trend",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _sparkline(confidenceSeries, Colors.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ALERT DISTRIBUTION
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Alert Severity Distribution",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Column(
                      children: severityCounts.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(e.key)),
                              Text(e.value.toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ================= SPARKLINE PAINTER =================

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height -
          ((data[i] - minVal) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
