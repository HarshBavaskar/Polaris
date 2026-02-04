import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:polaris_dashboard/core/global_reload.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/models/prediction.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  List<Prediction> data = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await ApiService.fetchPredictionHistory();
      setState(() {
        data = d;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  List<FlSpot> _riskSpots() {
    return List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i].riskScore),
    );
  }

  List<FlSpot> _confidenceSpots() {
    return List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i].confidence),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<GlobalReload>();
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.isEmpty) {
      return const Center(child: Text("No trend data available."));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Risk Score Trend",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 1,
                lineBarsData: [
                  LineChartBarData(
                    spots: _riskSpots(),
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Confidence Trend",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 1,
                lineBarsData: [
                  LineChartBarData(
                    spots: _confidenceSpots(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
