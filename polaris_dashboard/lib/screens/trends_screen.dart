import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
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

  final String baseUrl = 'http://localhost:8000';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadAll());
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
      final res = await http.get(Uri.parse('$baseUrl/dashboard/risk-timeseries'));
      if (res.statusCode != 200) return;

      final List data = jsonDecode(res.body);
      riskSeries = data.map<double>((e) => (e['risk_score'] ?? 0).toDouble()).toList();
    } catch (_) {}
  }

  Future<void> _loadConfidenceTrend() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/dashboard/confidence-timeseries'));
      if (res.statusCode != 200) return;

      final List data = jsonDecode(res.body);
      confidenceSeries = data.map<double>((e) => (e['confidence'] ?? 0).toDouble()).toList();
    } catch (_) {}
  }

  Future<void> _loadAlertDistribution() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/alerts/history'));
      if (res.statusCode != 200) return;

      final List alerts = jsonDecode(res.body);
      severityCounts.clear();
      for (final a in alerts) {
        final sev = a['severity']?.toString() ?? 'UNKNOWN';
        severityCounts[sev] = (severityCounts[sev] ?? 0) + 1;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'System Trends',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        _ChartCard(
          title: 'Risk Score Trend',
          subtitle: 'Latest risk progression',
          child: _lineChart(riskSeries, const Color(0xFFE53E3E)),
        ),
        const SizedBox(height: 14),
        _ChartCard(
          title: 'Confidence Trend',
          subtitle: 'Model confidence over time',
          child: _lineChart(confidenceSeries, const Color(0xFF3182CE)),
        ),
        const SizedBox(height: 14),
        _ChartCard(
          title: 'Alert Severity Distribution',
          subtitle: 'Total dispatch count by severity',
          child: _barChart(),
        ),
      ],
    );
  }

  Widget _lineChart(List<double> data, Color color) {
    if (data.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('No data available')));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: (minY - 0.05).clamp(0, 1).toDouble(),
          maxY: (maxY + 0.05).clamp(0, 1).toDouble(),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 34),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: color,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barChart() {
    if (severityCounts.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('No alert distribution data')));
    }

    final entries = severityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 34),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(entries[index].key, style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(entries.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  color: const Color(0xFF0C6E90),
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
