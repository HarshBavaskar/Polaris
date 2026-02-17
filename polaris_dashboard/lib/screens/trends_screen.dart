import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api.dart';
import '../core/refresh_config.dart';
import '../widgets/animated_reveal.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  List<double> riskSeries = [];
  List<double> confidenceSeries = [];
  Map<String, int> severityCounts = {};

  bool loading = true;
  final String baseUrl = ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _refreshTimer = Timer.periodic(RefreshConfig.trendsPoll, (_) => _loadAll());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    await Future.wait([
      _loadRiskTrend(),
      _loadConfidenceTrend(),
      _loadAlertDistribution(),
    ]);

    if (mounted) {
      setState(() => loading = false);
    }
    _isRefreshing = false;
  }

  Future<void> _loadRiskTrend() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/dashboard/risk-timeseries'),
      );
      if (res.statusCode != 200) return;

      final List data = jsonDecode(res.body);
      riskSeries = data.map<double>((e) {
        final map = e as Map<String, dynamic>;
        final value =
            map['ensemble_score'] ?? map['risk_score'] ?? map['risk'] ?? 0;
        return (value as num).toDouble();
      }).toList();
    } catch (_) {}
  }

  Future<void> _loadConfidenceTrend() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/dashboard/confidence-timeseries'),
      );
      if (res.statusCode != 200) return;

      final List data = jsonDecode(res.body);
      confidenceSeries = data
          .map<double>((e) => (e['confidence'] ?? 0).toDouble())
          .toList();
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

    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isCompact = MediaQuery.sizeOf(context).width < 980;
    final compactUi = isCompact || isAndroidUi;
    final latestRisk = riskSeries.isEmpty ? '--' : riskSeries.last.toStringAsFixed(2);
    final latestConfidence =
        confidenceSeries.isEmpty ? '--' : confidenceSeries.last.toStringAsFixed(2);
    final totalAlerts = severityCounts.values.fold<int>(0, (a, b) => a + b).toString();
    return ListView(
      padding: EdgeInsets.all(compactUi ? 12 : 24),
      children: [
        Text(
          'System Trends',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          compactUi
              ? 'One chart at a time for clear monitoring'
              : 'Risk, confidence and alert distribution trends',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        if (compactUi)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniStat(context, 'Risk', latestRisk),
              _miniStat(context, 'Confidence', latestConfidence),
              _miniStat(context, 'Alerts', totalAlerts),
            ],
          ),
        if (compactUi) const SizedBox(height: 10),
        if (compactUi) ...[
          AnimatedReveal(
            delay: const Duration(milliseconds: 40),
            child: _compactSlidingTabs(),
          ),
        ] else ...[
          AnimatedReveal(
            delay: const Duration(milliseconds: 40),
            child: _ChartCard(
              title: 'Risk Score Trend',
              subtitle: 'Latest risk progression',
              child: _lineChart(riskSeries, const Color(0xFFE53E3E)),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedReveal(
            delay: const Duration(milliseconds: 90),
            child: _ChartCard(
              title: 'Confidence Trend',
              subtitle: 'Model confidence over time',
              child: _lineChart(confidenceSeries, const Color(0xFF3182CE)),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedReveal(
            delay: const Duration(milliseconds: 140),
            child: _ChartCard(
              title: 'Alert Severity Distribution',
              subtitle: 'Total dispatch count by severity',
              child: _barChart(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _compactSlidingTabs() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            isScrollable: false,
            tabs: const [
              Tab(text: 'Risk'),
              Tab(text: 'Confidence'),
              Tab(text: 'Alerts'),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 290,
            child: TabBarView(
              children: [
                _ChartCard(
                  title: 'Risk Score Trend',
                  subtitle: 'Latest risk progression',
                  child: _lineChart(
                    riskSeries,
                    const Color(0xFFE53E3E),
                    compact: true,
                  ),
                ),
                _ChartCard(
                  title: 'Confidence Trend',
                  subtitle: 'Model confidence over time',
                  child: _lineChart(
                    confidenceSeries,
                    const Color(0xFF3182CE),
                    compact: true,
                  ),
                ),
                _ChartCard(
                  title: 'Alert Severity Distribution',
                  subtitle: 'Total dispatch count by severity',
                  child: _barChart(compact: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineChart(List<double> data, Color color, {bool compact = false}) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No data available')),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: compact ? 190 : 220,
      child: LineChart(
        LineChartData(
          minY: (minY - 0.05).clamp(0, 1).toDouble(),
          maxY: (maxY + 0.05).clamp(0, 1).toDouble(),
          gridData: FlGridData(
            show: !compact,
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: !compact,
                reservedSize: 34,
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: compact ? 2.5 : 3,
              color: color,
              dotData: FlDotData(show: !compact && data.length < 18),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: compact ? 0.12 : 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barChart({bool compact = false}) {
    if (severityCounts.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No alert distribution data')),
      );
    }

    final entries = severityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: compact ? 190 : 220,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: !compact,
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: !compact,
                reservedSize: 34,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      entries[index].key,
                      style: TextStyle(fontSize: compact ? 10 : 11),
                    ),
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
                  width: compact ? 14 : 18,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
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
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
