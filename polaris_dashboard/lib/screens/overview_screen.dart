import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/refresh_config.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Timer? _cameraTimer;
  Timer? _decisionTimer;
  bool _isFetchingDecision = false;

  String _frameUrl = '';
  Map<String, dynamic>? decision;

  final String baseUrl = 'http://localhost:8000';
  final String cameraEndpoint = 'http://localhost:8000/camera/latest-frame';

  @override
  void initState() {
    super.initState();
    _refreshFrame();
    _fetchDecision();

    _cameraTimer = Timer.periodic(RefreshConfig.overviewCameraPoll, (_) => _refreshFrame());
    _decisionTimer = Timer.periodic(RefreshConfig.overviewDecisionPoll, (_) => _fetchDecision());
  }

  @override
  void dispose() {
    _cameraTimer?.cancel();
    _decisionTimer?.cancel();
    super.dispose();
  }

  void _refreshFrame() {
    setState(() {
      _frameUrl = '$cameraEndpoint?ts=${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  Future<void> _fetchDecision() async {
    if (_isFetchingDecision) return;
    _isFetchingDecision = true;
    try {
      final res = await http.get(Uri.parse('$baseUrl/decision/latest'));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      if (data.isEmpty) return;

      setState(() => decision = data);
    } catch (_) {
    } finally {
      _isFetchingDecision = false;
    }
  }

  Color _riskColor(String? risk) {
    switch (risk) {
      case 'IMMINENT':
        return const Color(0xFFC53030);
      case 'WARNING':
        return const Color(0xFFDD6B20);
      case 'WATCH':
        return const Color(0xFFD69E2E);
      default:
        return const Color(0xFF2F855A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 1080;

    final stats = <_MetricData>[
      _MetricData(
        title: 'Current Risk',
        value: decision?['final_risk_level']?.toString() ?? '--',
        color: _riskColor(decision?['final_risk_level']?.toString()),
        icon: Icons.warning_amber_rounded,
      ),
      _MetricData(
        title: 'Alert Severity',
        value: decision?['final_alert_severity']?.toString() ?? '--',
        color: _riskColor(decision?['final_alert_severity']?.toString()),
        icon: Icons.notification_important_rounded,
      ),
      _MetricData(
        title: 'Decision Mode',
        value: decision?['decision_mode']?.toString() ?? '--',
        color: decision?['decision_mode'] == 'MANUAL_OVERRIDE'
            ? const Color(0xFFC53030)
            : colorScheme.primary,
        icon: Icons.settings_suggest_rounded,
      ),
      _MetricData(
        title: 'ETA',
        value: decision?['final_eta']?.toString() ?? '--',
        color: colorScheme.secondary,
        icon: Icons.schedule_rounded,
      ),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        _refreshFrame();
        await _fetchDecision();
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Authority Overview',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  _refreshFrame();
                  _fetchDecision();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isCompact) ...[
            _cameraCard(context),
            const SizedBox(height: 16),
            ...stats.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MetricCard(data: s),
                )),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _cameraCard(context)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: stats
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _MetricCard(data: s),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cameraCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: colorScheme.surfaceContainerHigh,
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Live Camera Feed',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00C36D),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _frameUrl.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Image.network(
                    _frameUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        'Camera feed unavailable',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: data.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.value,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
