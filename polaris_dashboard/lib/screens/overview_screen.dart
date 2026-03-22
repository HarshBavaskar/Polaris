import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api.dart';
import '../core/api_service.dart';
import '../core/models/override_state.dart';
import '../core/models/safe_zone.dart';
import '../core/models/teams_snapshot.dart';
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
  bool _isFetchingFrame = false;
  bool _isFetchingDecision = false;
  bool _isFetchingOverview = false;
  bool _showCameraOnAndroid = false;

  String _frameUrl = '';
  Map<String, dynamic>? decision;
  List<SafeZone> _safeZones = const [];
  int _overrideHistoryCount = 0;
  TeamsSnapshot? _teamsSnapshot;

  final String baseUrl = ApiConfig.baseUrl;
  final String cameraEndpoint = '${ApiConfig.baseUrl}/camera/latest-frame';

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
    await _refreshFrame();
    await _refreshLiveData();
  }

  Future<void> _refreshLiveData() async {
    await Future.wait<void>([_fetchDecision(), _refreshOverviewData()]);
  }

  Future<void> _refreshFrame() async {
    if (_isFetchingFrame || !mounted) return;
    _isFetchingFrame = true;

    final nextUrl = '$cameraEndpoint?ts=${DateTime.now().millisecondsSinceEpoch}';
    final provider = NetworkImage(nextUrl);

    try {
      await precacheImage(provider, context);
      if (!mounted) return;
      setState(() {
        _frameUrl = nextUrl;
      });
    } catch (_) {
      if (!mounted || _frameUrl.isNotEmpty) return;
      setState(() {
        _frameUrl = nextUrl;
      });
    } finally {
      _isFetchingFrame = false;
    }
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

    final safeZonesFuture = ApiService.fetchSafeZones().catchError(
      (_) => <SafeZone>[],
    );
    final overrideHistoryFuture = ApiService.fetchOverrideHistory().catchError(
      (_) => <OverrideState>[],
    );
    final teamsSnapshotFuture = ApiService.fetchTeamsSnapshot().catchError(
      (_) => _emptyTeamsSnapshot(),
    );

    try {
      final results = await Future.wait<dynamic>([
        safeZonesFuture,
        overrideHistoryFuture,
        teamsSnapshotFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _safeZones = results[0] as List<SafeZone>;
        _overrideHistoryCount = (results[1] as List<OverrideState>).length;
        _teamsSnapshot = results[2] as TeamsSnapshot;
      });
    } finally {
      _isFetchingOverview = false;
    }
  }

  TeamsSnapshot _emptyTeamsSnapshot() {
    return TeamsSnapshot(
      teams: const [],
      helpRequests: const [],
      stats: TeamStats(
        totalTeams: 0,
        availableTeams: 0,
        deployedTeams: 0,
        offlineTeams: 0,
        totalMembers: 0,
        openHelpRequests: 0,
        assignedHelpRequests: 0,
        notificationsSent: 0,
      ),
    );
  }

  Color _riskColor(String? risk) {
    switch ((risk ?? '').toUpperCase()) {
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

  int _riskLevel(String? risk) {
    switch ((risk ?? '').toUpperCase()) {
      case 'IMMINENT':
      case 'EMERGENCY':
        return 4;
      case 'WARNING':
      case 'ALERT':
        return 3;
      case 'WATCH':
      case 'ADVISORY':
        return 2;
      case 'SAFE':
      case 'INFO':
        return 1;
      default:
        return 0;
    }
  }

  String _displayLabel(
    dynamic value, {
    String fallback = '--',
  }) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw.toUpperCase() == 'UNKNOWN' || raw == 'null') {
      return fallback;
    }

    return raw
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  double? _confidencePercent(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null) return null;
    if (parsed <= 1) return (parsed * 100).clamp(0, 100).toDouble();
    return parsed.clamp(0, 100).toDouble();
  }

  String _confidenceLabel(dynamic value) {
    final percent = _confidencePercent(value);
    if (percent == null) return '--';
    return '${percent.round()}%';
  }

  String _threatHeadline({
    required bool isManualMode,
    required int riskLevel,
    required int severityLevel,
  }) {
    if (isManualMode) return 'Manual override is directing the response';
    if (riskLevel >= 4 || severityLevel >= 4) {
      return 'Immediate command attention is required';
    }
    if (riskLevel >= 3 || severityLevel >= 3) {
      return 'Escalated conditions are actively developing';
    }
    if (riskLevel >= 2 || severityLevel >= 2) {
      return 'Conditions are elevated and under watch';
    }
    return 'Situation is stable and under observation';
  }

  String _threatSubline({
    required String modeLabel,
    required String etaLabel,
    required int openRequests,
  }) {
    final requestText = openRequests == 1
        ? '1 open field request'
        : '$openRequests open field requests';
    return '$modeLabel mode, ETA $etaLabel, $requestText';
  }

  double _cameraFeedHeight(BuildContext context, {required bool dense}) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final reservedHeight = dense ? 270.0 : 300.0;
    return (screenHeight - reservedHeight).clamp(
      dense ? 220.0 : 320.0,
      dense ? 420.0 : 640.0,
    );
  }

  double _cameraCardHeight(BuildContext context, {required bool dense}) {
    return _cameraFeedHeight(context, dense: dense) + (dense ? 56 : 64);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isCompact = width < 1080 || isAndroidUi;

    final manualSafeZones = _safeZones
        .where((z) => z.active && z.source.toUpperCase() == 'MANUAL')
        .length;
    final teamStats = _teamsSnapshot?.stats;

    final decisionMode =
        (decision?['decision_mode'] ?? decision?['decision_state'])
            ?.toString() ??
        '';
    final riskLevel = _riskLevel(decision?['final_risk_level']?.toString());
    final severityLevel = _riskLevel(
      decision?['final_alert_severity']?.toString(),
    );
    final isManualMode = decisionMode.toUpperCase() == 'MANUAL_OVERRIDE';
    final totalTeams = teamStats?.totalTeams ?? 0;
    final availableTeams = teamStats?.availableTeams ?? 0;
    final deployedTeams = teamStats?.deployedTeams ?? 0;
    final offlineTeams = teamStats?.offlineTeams ?? 0;
    final openRequests = teamStats?.openHelpRequests ?? 0;
    final assignedRequests = teamStats?.assignedHelpRequests ?? 0;
    final responders = teamStats?.totalMembers ?? 0;
    final notifications = teamStats?.notificationsSent ?? 0;
    final showCamera = !isAndroidUi || _showCameraOnAndroid;
    final desktopThreatMinHeight = isCompact
        ? null
        : _cameraCardHeight(context, dense: false);

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: EdgeInsets.all(isCompact ? 12 : 24),
        children: [
          if (isCompact)
            AnimatedReveal(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Authority Overview',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live status, alerts and readiness at a glance',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _refreshAll,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                    ),
                  ),
                ],
              ),
            )
          else
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
                        const SizedBox(height: 4),
                        Text(
                          'Live status, alerts and readiness at a glance',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
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
          if (isAndroidUi)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _showCameraOnAndroid = !_showCameraOnAndroid);
                },
                icon: Icon(
                  _showCameraOnAndroid
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                label: Text(
                  _showCameraOnAndroid
                      ? 'Hide Camera Feed'
                      : 'Show Camera Feed',
                ),
              ),
            ),
          if (showCamera) ...[
            if (isCompact) ...[
              AnimatedReveal(
                delay: const Duration(milliseconds: 80),
                child: _cameraFeedCard(context, dense: isAndroidUi),
              ),
              const SizedBox(height: 12),
              AnimatedReveal(
                delay: const Duration(milliseconds: 120),
                child: _commandPulseBoard(
                  context,
                  dense: isAndroidUi,
                  riskLevel: riskLevel,
                  severityLevel: severityLevel,
                  isManualMode: isManualMode,
                  manualSafeZones: manualSafeZones,
                  overrideHistoryCount: _overrideHistoryCount,
                  totalTeams: totalTeams,
                  availableTeams: availableTeams,
                  deployedTeams: deployedTeams,
                  offlineTeams: offlineTeams,
                  openRequests: openRequests,
                  assignedRequests: assignedRequests,
                  responders: responders,
                  notifications: notifications,
                ),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: AnimatedReveal(
                      delay: const Duration(milliseconds: 80),
                      child: _cameraFeedCard(context, dense: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: AnimatedReveal(
                      delay: const Duration(milliseconds: 120),
                      child: _commandPulseBoard(
                        context,
                        dense: false,
                        riskLevel: riskLevel,
                        severityLevel: severityLevel,
                        isManualMode: isManualMode,
                        manualSafeZones: manualSafeZones,
                        overrideHistoryCount: _overrideHistoryCount,
                        totalTeams: totalTeams,
                        availableTeams: availableTeams,
                        deployedTeams: deployedTeams,
                        offlineTeams: offlineTeams,
                        openRequests: openRequests,
                        assignedRequests: assignedRequests,
                        responders: responders,
                        notifications: notifications,
                        showThreatDecision: true,
                        showTeamDistribution: false,
                        showOperationalSignals: false,
                        minHeight: desktopThreatMinHeight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedReveal(
                delay: const Duration(milliseconds: 150),
                child: _commandPulseBoard(
                  context,
                  dense: false,
                  riskLevel: riskLevel,
                  severityLevel: severityLevel,
                  isManualMode: isManualMode,
                  manualSafeZones: manualSafeZones,
                  overrideHistoryCount: _overrideHistoryCount,
                  totalTeams: totalTeams,
                  availableTeams: availableTeams,
                  deployedTeams: deployedTeams,
                  offlineTeams: offlineTeams,
                  openRequests: openRequests,
                  assignedRequests: assignedRequests,
                  responders: responders,
                  notifications: notifications,
                  showThreatDecision: false,
                  showTeamDistribution: true,
                  showOperationalSignals: true,
                ),
              ),
            ],
          ] else
            AnimatedReveal(
              delay: const Duration(milliseconds: 120),
              child: _commandPulseBoard(
                context,
                dense: isAndroidUi,
                riskLevel: riskLevel,
                severityLevel: severityLevel,
                isManualMode: isManualMode,
                manualSafeZones: manualSafeZones,
                overrideHistoryCount: _overrideHistoryCount,
                totalTeams: totalTeams,
                availableTeams: availableTeams,
                deployedTeams: deployedTeams,
                offlineTeams: offlineTeams,
                openRequests: openRequests,
                assignedRequests: assignedRequests,
                responders: responders,
                notifications: notifications,
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _commandPulseBoard(
    BuildContext context, {
    required bool dense,
    required int riskLevel,
    required int severityLevel,
    required bool isManualMode,
    required int manualSafeZones,
    required int overrideHistoryCount,
    required int totalTeams,
    required int availableTeams,
    required int deployedTeams,
    required int offlineTeams,
    required int openRequests,
    required int assignedRequests,
    required int responders,
    required int notifications,
    bool showThreatDecision = true,
    bool showTeamDistribution = true,
    bool showOperationalSignals = true,
    double? minHeight,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final riskColor = _riskColor(decision?['final_risk_level']?.toString());
    final severityColor = _riskColor(
      decision?['final_alert_severity']?.toString(),
    );
    final modeColor = isManualMode
        ? const Color(0xFFC53030)
        : colorScheme.primary;
    final critical = riskLevel >= 3 || severityLevel >= 3 || openRequests > 0;
    final threatOnly =
        showThreatDecision && !showTeamDistribution && !showOperationalSignals;
    final riskLabel = _displayLabel(decision?['final_risk_level']);
    final severityLabel = _displayLabel(decision?['final_alert_severity']);
    final modeLabel = _displayLabel(
      decision?['decision_mode'] ?? decision?['decision_state'],
      fallback: isManualMode ? 'Manual Override' : 'Automated',
    );
    final etaLabel = _displayLabel(
      decision?['final_eta'],
      fallback: 'Pending',
    );
    final etaConfidenceLabel = _displayLabel(
      decision?['final_eta_confidence'],
      fallback: 'Unknown',
    );
    final confidenceLabel = _confidenceLabel(decision?['final_confidence']);
    final confidencePercent = _confidencePercent(decision?['final_confidence']);
    final statusProgress = ((riskLevel.clamp(0, 4) + severityLevel.clamp(0, 4)) /
            8)
        .clamp(0.2, 1.0)
        .toDouble();

    return _AttentionPulse(
      enabled: critical,
      color: riskColor,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight ?? 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerLowest,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _decisionStatusRail(
                color: riskColor,
                progress: statusProgress,
                label: riskLabel,
              ),
              Padding(
                padding: EdgeInsets.all(dense ? 12 : 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                final detailTileWidth = dense || constraints.maxWidth < 430
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 8) / 2;
                final threatHero = Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(dense ? 10 : 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        riskColor.withValues(alpha: 0.18),
                        riskColor.withValues(alpha: 0.06),
                      ],
                    ),
                    border: Border.all(
                      color: riskColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: dense ? 40 : 44,
                        height: dense ? 40 : 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: riskColor.withValues(alpha: 0.14),
                        ),
                        child: Icon(
                          isManualMode
                              ? Icons.admin_panel_settings_rounded
                              : Icons.track_changes_rounded,
                          color: riskColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _threatHeadline(
                                isManualMode: isManualMode,
                                riskLevel: riskLevel,
                                severityLevel: severityLevel,
                              ),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _threatSubline(
                                modeLabel: modeLabel,
                                etaLabel: etaLabel,
                                openRequests: openRequests,
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                final decisionDetails = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: detailTileWidth,
                      child: _decisionDetailTile(
                        context,
                        icon: Icons.warning_amber_rounded,
                        label: 'Current Risk',
                        value: riskLabel,
                        caption: 'Threat posture now',
                        color: riskColor,
                      ),
                    ),
                    SizedBox(
                      width: detailTileWidth,
                      child: _decisionDetailTile(
                        context,
                        icon: Icons.notification_important_rounded,
                        label: 'Alert Severity',
                        value: severityLabel,
                        caption: 'Notification urgency',
                        color: severityColor,
                      ),
                    ),
                    SizedBox(
                      width: detailTileWidth,
                      child: _decisionDetailTile(
                        context,
                        icon: Icons.schedule_rounded,
                        label: 'Projected ETA',
                        value: etaLabel,
                        caption: 'Expected response window',
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                    SizedBox(
                      width: detailTileWidth,
                      child: _decisionDetailTile(
                        context,
                        icon: Icons.analytics_rounded,
                        label: 'Decision Confidence',
                        value: confidenceLabel,
                        caption: confidencePercent == null
                            ? 'Awaiting model certainty'
                            : 'Model certainty right now',
                        color: modeColor,
                      ),
                    ),
                  ],
                );
                final decisionContext = _signalSectionBox(
                  context,
                  title: 'Decision Context',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _decisionContextPill(
                        context,
                        icon: Icons.settings_suggest_rounded,
                        label: 'Mode',
                        value: modeLabel,
                        color: modeColor,
                      ),
                      _decisionContextPill(
                        context,
                        icon: Icons.av_timer_rounded,
                        label: 'ETA Confidence',
                        value: etaConfidenceLabel,
                        color: const Color(0xFF0F766E),
                      ),
                      _decisionContextPill(
                        context,
                        icon: Icons.sos_rounded,
                        label: 'Open Requests',
                        value: openRequests.toString(),
                        color: const Color(0xFFC53030),
                      ),
                      _decisionContextPill(
                        context,
                        icon: Icons.health_and_safety_rounded,
                        label: 'Manual Zones',
                        value: manualSafeZones.toString(),
                        color: const Color(0xFF2F855A),
                      ),
                      _decisionContextPill(
                        context,
                        icon: Icons.local_shipping_rounded,
                        label: 'Teams Deployed',
                        value: deployedTeams.toString(),
                        color: const Color(0xFFDD6B20),
                      ),
                    ],
                  ),
                );
                final operationalPanel = Column(
                  children: [
                    _signalSectionBox(
                      context,
                      title: 'Authority Actions',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _statBadge(
                            context,
                            icon: Icons.health_and_safety_rounded,
                            color: const Color(0xFF2F855A),
                            label: 'Manual Zones',
                            value: manualSafeZones,
                          ),
                          _statBadge(
                            context,
                            icon: Icons.history_rounded,
                            color: colorScheme.primary,
                            label: 'Override Log',
                            value: overrideHistoryCount,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _signalSectionBox(
                      context,
                      title: 'Dispatch Flow',
                      child: _dispatchFlow(
                        context,
                        openRequests: openRequests,
                        assignedRequests: assignedRequests,
                        notifications: notifications,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _signalSectionBox(
                      context,
                      title: 'Response Capacity',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _statBadge(
                            context,
                            icon: Icons.support_agent_rounded,
                            color: const Color(0xFF0F766E),
                            label: 'Responders Ready',
                            value: responders,
                          ),
                          _statBadge(
                            context,
                            icon: Icons.groups_rounded,
                            color: colorScheme.primary,
                            label: 'Total Teams',
                            value: totalTeams,
                          ),
                          _statBadge(
                            context,
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF2F855A),
                            label: 'Teams Available',
                            value: availableTeams,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final threatDecisionContent = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Threat & Decision',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    threatHero,
                    const SizedBox(height: 10),
                    decisionDetails,
                    if (threatOnly) ...[
                      const SizedBox(height: 10),
                      decisionContext,
                    ],
                  ],
                );

                final leftContent = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showThreatDecision) threatDecisionContent,
                    if (showTeamDistribution) ...[
                      if (showThreatDecision) const SizedBox(height: 10),
                      Text(
                        'Team Distribution',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _teamFlowRail(
                        availableTeams: availableTeams,
                        deployedTeams: deployedTeams,
                        offlineTeams: offlineTeams,
                      ),
                    ],
                    if (showOperationalSignals) ...[
                      if (showThreatDecision || showTeamDistribution)
                        const SizedBox(height: 10),
                      Text(
                        'Operational Signals',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      operationalPanel,
                    ],
                  ],
                );

                return leftContent;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _decisionDetailTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String caption,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _decisionStatusRail({
    required Color color,
    required double progress,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      height: 8,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          key: ValueKey('${color.value}_${progress}_$label'),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: progress),
          builder: (context, value, _) {
            return FractionallySizedBox(
              widthFactor: value,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.6),
                      color,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _teamFlowRail({
    required int availableTeams,
    required int deployedTeams,
    required int offlineTeams,
  }) {
    final total = availableTeams + deployedTeams + offlineTeams;
    final all = total == 0 ? 1 : total;
    return Tooltip(
      message:
          'Available: $availableTeams | Deployed: $deployedTeams | Offline: $offlineTeams',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: availableTeams == 0 ? 1 : availableTeams,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    tween: Tween<double>(
                      begin: 0,
                      end: availableTeams / all,
                    ),
                    builder: (context, value, child) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F855A).withValues(
                            alpha: availableTeams == 0 ? 0.15 : 0.9,
                          ),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(999),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: deployedTeams == 0 ? 1 : deployedTeams,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 14,
                    color: const Color(0xFFDD6B20).withValues(
                      alpha: deployedTeams == 0 ? 0.15 : 0.9,
                    ),
                  ),
                ),
                Expanded(
                  flex: offlineTeams == 0 ? 1 : offlineTeams,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A5568).withValues(
                        alpha: offlineTeams == 0 ? 0.15 : 0.9,
                      ),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _flowLegendItem(
                    context,
                    label: 'Available',
                    value: availableTeams,
                    color: const Color(0xFF2F855A),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _flowLegendItem(
                    context,
                    label: 'Deployed',
                    value: deployedTeams,
                    color: const Color(0xFFDD6B20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _flowLegendItem(
                    context,
                    label: 'Offline',
                    value: offlineTeams,
                    color: const Color(0xFF4A5568),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowLegendItem(
    BuildContext context, {
    required String label,
    required int value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _signalSectionBox(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _statBadge(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: value.toDouble()),
            builder: (context, animatedValue, _) {
              return Text(
                animatedValue.round().toString(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _decisionContextPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dispatchFlow(
    BuildContext context, {
    required int openRequests,
    required int assignedRequests,
    required int notifications,
  }) {
    return Row(
      children: [
        Expanded(
          child: _flowNode(
            context,
            icon: Icons.sos_rounded,
            color: const Color(0xFFC53030),
            label: 'Open',
            value: openRequests,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 18),
        ),
        Expanded(
          child: _flowNode(
            context,
            icon: Icons.assignment_ind_rounded,
            color: const Color(0xFFB7791F),
            label: 'Assigned',
            value: assignedRequests,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 18),
        ),
        Expanded(
          child: _flowNode(
            context,
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFF6B46C1),
            label: 'Notified',
            value: notifications,
          ),
        ),
      ],
    );
  }

  Widget _flowNode(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: value.toDouble()),
            builder: (context, animatedValue, _) {
              return Text(
                animatedValue.round().toString(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraFeedCard(
    BuildContext context, {
    required bool dense,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final feedHeight = _cameraFeedHeight(context, dense: dense);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 10 : 12,
              vertical: dense ? 8 : 10,
            ),
            color: colorScheme.surfaceContainerHigh,
            child: Row(
              children: [
                Icon(
                  Icons.videocam_rounded,
                  size: dense ? 16 : 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Camera Feed',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Real-time surveillance frame',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00C36D),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: feedHeight,
            width: double.infinity,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Colors.black),
              child: _frameUrl.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Image.network(
                      _frameUrl,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          'Camera feed unavailable',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
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
    if (!widget.enabled) {
      _controller.stop();
      _controller.value = 0;
      return;
    }

    if (!oldWidget.enabled) {
      _controller.repeat(reverse: true);
      return;
    }

    if (oldWidget.color != widget.color) {
      _controller
        ..stop()
        ..value = 0
        ..repeat(reverse: true);
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
