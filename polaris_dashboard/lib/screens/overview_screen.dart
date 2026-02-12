import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api_service.dart';
import '../core/models/alert_event.dart';
import '../core/models/citizen_report.dart';
import '../core/models/risk_point.dart';
import '../core/models/safe_zone.dart';
import '../core/refresh_config.dart';
import '../widgets/animated_reveal.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Timer? _cameraTimer;
  Timer? _decisionTimer;
  bool _isFetchingDecision = false;
  bool _isFetchingOverview = false;

  String _frameUrl = '';
  Map<String, dynamic>? decision;
  List<RiskPoint> _mapSummaryRiskPoints = const [];
  List<SafeZone> _safeZones = const [];
  List<AlertEvent> _alertHistory = const [];
  List<CitizenReport> _pendingReports = const [];

  final String baseUrl = 'http://localhost:8000';
  final String cameraEndpoint = 'http://localhost:8000/camera/latest-frame';

  @override
  void initState() {
    super.initState();
    _refreshAll();

    _cameraTimer = Timer.periodic(
      RefreshConfig.overviewCameraPoll,
      (_) => _refreshFrame(),
    );
    _decisionTimer = Timer.periodic(
      RefreshConfig.overviewDecisionPoll,
      (_) => _refreshLiveData(),
    );
  }

  @override
  void dispose() {
    _cameraTimer?.cancel();
    _decisionTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    _refreshFrame();
    await _refreshLiveData();
  }

  Future<void> _refreshLiveData() async {
    await Future.wait<void>([_fetchDecision(), _refreshOverviewData()]);
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

      if (!mounted) return;
      setState(() => decision = data);
    } catch (_) {
      // Fail silently, overview still renders from cached/other sections.
    } finally {
      _isFetchingDecision = false;
    }
  }

  Future<void> _refreshOverviewData() async {
    if (_isFetchingOverview) return;
    _isFetchingOverview = true;

    final liveRiskFuture = ApiService.fetchLiveRiskPoints().catchError(
      (_) => <RiskPoint>[],
    );
    final safeZonesFuture = ApiService.fetchSafeZones().catchError(
      (_) => <SafeZone>[],
    );
    final alertHistoryFuture = ApiService.fetchAlertHistory().catchError(
      (_) => <AlertEvent>[],
    );
    final pendingReportsFuture = ApiService.fetchPendingCitizenReports()
        .catchError((_) => <CitizenReport>[]);

    try {
      final results = await Future.wait<dynamic>([
        liveRiskFuture,
        safeZonesFuture,
        alertHistoryFuture,
        pendingReportsFuture,
      ]);

      if (!mounted) return;
      final liveRisk = results[0] as List<RiskPoint>;
      setState(() {
        _mapSummaryRiskPoints = _latestRiskPerExactLocation(liveRisk);
        _safeZones = results[1] as List<SafeZone>;
        _alertHistory = results[2] as List<AlertEvent>;
        _pendingReports = results[3] as List<CitizenReport>;
      });
    } finally {
      _isFetchingOverview = false;
    }
  }

  Color _riskColor(String? risk) {
    switch (risk) {
      case 'IMMINENT':
      case 'EMERGENCY':
        return const Color(0xFFC53030);
      case 'WARNING':
      case 'ALERT':
        return const Color(0xFFDD6B20);
      case 'WATCH':
        return const Color(0xFFD69E2E);
      default:
        return const Color(0xFF2F855A);
    }
  }

  bool _isActiveAlert(AlertEvent event) {
    final s = event.severity.toUpperCase();
    return s.contains('EMERGENCY') ||
        s.contains('IMMINENT') ||
        s.contains('ALERT') ||
        s.contains('WARNING') ||
        s.contains('WATCH');
  }

  List<RiskPoint> _latestRiskPerExactLocation(List<RiskPoint> points) {
    final byLocation = <String, RiskPoint>{};

    for (final point in points) {
      final key = '${point.lat},${point.lng}';
      final current = byLocation[key];

      if (current == null) {
        byLocation[key] = point;
        continue;
      }

      final currentTs = current.timestamp;
      final nextTs = point.timestamp;

      if (currentTs == null && nextTs == null) {
        if (point.riskScore >= current.riskScore) {
          byLocation[key] = point;
        }
        continue;
      }

      if (nextTs != null && (currentTs == null || nextTs.isAfter(currentTs))) {
        byLocation[key] = point;
      }
    }

    return byLocation.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 1080;

    final activeSafeZones = _safeZones.where((z) => z.active).length;
    final riskPointsFromMapSummary = _mapSummaryRiskPoints.length;
    final riskZonesPresent = _mapSummaryRiskPoints
        .where((p) => p.riskScore > 0)
        .length;
    final activeAlerts = _alertHistory.where(_isActiveAlert).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final decisionStats = <_MetricData>[
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

    final importantStats = <_OverviewStatData>[
      _OverviewStatData(
        title: 'Risk Points',
        value: riskPointsFromMapSummary.toString(),
        subtitle: 'Latest from map summary',
        icon: Icons.place_rounded,
      ),
      _OverviewStatData(
        title: 'Risk Zones Present',
        value: riskZonesPresent.toString(),
        subtitle: 'Only zones currently present',
        icon: Icons.report_problem_rounded,
      ),
      _OverviewStatData(
        title: 'Active Alerts',
        value: activeAlerts.length.toString(),
        subtitle: 'Needs authority review',
        icon: Icons.campaign_rounded,
      ),
      _OverviewStatData(
        title: 'Pending Reports',
        value: _pendingReports.length.toString(),
        subtitle: 'Citizen verification queue',
        icon: Icons.fact_check_rounded,
      ),
      _OverviewStatData(
        title: 'Safe Zones Active',
        value: activeSafeZones.toString(),
        subtitle: 'Evacuation safe points',
        icon: Icons.health_and_safety_rounded,
      ),
    ];

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedReveal(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Authority Overview',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isCompact) ...[
            AnimatedReveal(
              delay: const Duration(milliseconds: 40),
              child: _cameraCard(context),
            ),
            const SizedBox(height: 16),
            ...List.generate(decisionStats.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnimatedReveal(
                  delay: Duration(milliseconds: 80 + (index * 55)),
                  child: _MetricCard(data: decisionStats[index]),
                ),
              );
            }),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AnimatedReveal(
                    delay: const Duration(milliseconds: 40),
                    child: _cameraCard(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: List.generate(decisionStats.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedReveal(
                          delay: Duration(milliseconds: 80 + (index * 55)),
                          child: _MetricCard(data: decisionStats[index]),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),
          AnimatedReveal(
            delay: const Duration(milliseconds: 120),
            child: _ImportantStatsCard(
              stats: importantStats,
              columns: width >= 1280
                  ? 4
                  : width >= 980
                  ? 3
                  : 2,
            ),
          ),
          const SizedBox(height: 6),
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

class _OverviewStatData {
  const _OverviewStatData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
}

class _ImportantStatsCard extends StatelessWidget {
  const _ImportantStatsCard({required this.stats, required this.columns});

  final List<_OverviewStatData> stats;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Important Stats',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: 3.25,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (context, index) =>
                  _OverviewStatTile(data: stats[index]),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewStatTile extends StatelessWidget {
  const _OverviewStatTile({required this.data});

  final _OverviewStatData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(data.icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
    final critical = _isCriticalValue(data.value);
    return _AttentionPulse(
      enabled: critical,
      color: data.color,
      child: Card(
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isCriticalValue(String value) {
    final normalized = value.toUpperCase();
    return normalized.contains('IMMINENT') ||
        normalized.contains('EMERGENCY') ||
        normalized.contains('WARNING');
  }
}

class _AttentionPulse extends StatefulWidget {
  const _AttentionPulse({
    required this.enabled,
    required this.color,
    required this.child,
  });

  final bool enabled;
  final Color color;
  final Widget child;

  @override
  State<_AttentionPulse> createState() => _AttentionPulseState();
}

class _AttentionPulseState extends State<_AttentionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AttentionPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.10 + (_controller.value * 0.14);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: pulse),
                blurRadius: 20,
                spreadRadius: 0.4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
