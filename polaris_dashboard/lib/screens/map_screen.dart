import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/refresh_config.dart';
import '../core/api_service.dart';
import '../core/api.dart';
import '../core/models/historical_incident.dart';
import '../core/models/risk_point.dart';
import '../core/models/safe_zone.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController mapController = MapController();

  List<RiskPoint> riskPoints = [];
  List<SafeZone> safeZones = [];
  List<HistoricalIncident> incidents = [];

  bool showSafeZones = true;
  bool showIncidents = true;
  bool _hasAutoCentered = false;
  bool _isLoading = false;
  bool _manualOverrideActive = false;
  bool _layersCollapsed = false;
  bool _summaryCollapsed = false;

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (isAndroidUi) {
      _layersCollapsed = true;
      _summaryCollapsed = true;
    }
    loadAll();
    refreshTimer = Timer.periodic(RefreshConfig.mapPoll, (_) => loadAll());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadAll() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final rp = await ApiService.fetchLiveRiskPoints();
      final sz = await ApiService.fetchSafeZones();
      final hi = await ApiService.fetchHistoricalIncidents();
      final uniqueRiskPoints = _latestRiskPerExactLocation(rp);
      final adjustedRiskPoints = await _applyLatestDecisionToRiskPoints(
        uniqueRiskPoints,
      );

      if (!mounted) return;

      setState(() {
        riskPoints = adjustedRiskPoints;
        safeZones = sz;
        incidents = hi;
      });

      if (!_hasAutoCentered && riskPoints.isNotEmpty) {
        final highest = riskPoints.reduce(
          (a, b) => a.riskScore > b.riskScore ? a : b,
        );
        mapController.move(LatLng(highest.lat, highest.lng), 12);
        _hasAutoCentered = true;
      }
    } catch (_) {
    } finally {
      _isLoading = false;
    }
  }

  Color riskColor(double riskScore) {
    if (riskScore >= 0.8) return const Color(0xFFE53E3E);
    if (riskScore >= 0.65) return const Color(0xFFDD6B20);
    if (riskScore >= 0.4) return const Color(0xFFD69E2E);
    return const Color(0xFF2F855A);
  }

  double _riskScoreFromLevel(String level) {
    return switch (level) {
      'IMMINENT' => 0.95,
      'WARNING' => 0.75,
      'WATCH' => 0.50,
      _ => 0.20,
    };
  }

  Future<List<RiskPoint>> _applyLatestDecisionToRiskPoints(
    List<RiskPoint> points,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/decision/latest'),
      );
      if (response.statusCode != 200) {
        _manualOverrideActive = false;
        return points;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        _manualOverrideActive = false;
        return points;
      }

      final mode = data['decision_mode']?.toString().toUpperCase() ?? '';
      _manualOverrideActive = mode == 'MANUAL_OVERRIDE';
      final level =
          data['final_risk_level']?.toString().toUpperCase() ?? 'SAFE';
      final liveScore = _riskScoreFromLevel(level);

      if (points.isEmpty) {
        return [
          RiskPoint(
            lat: 19.0760,
            lng: 72.8777,
            riskScore: liveScore,
            timestamp: DateTime.now(),
          ),
        ];
      }

      return points.map((p) {
        return RiskPoint(
          lat: p.lat,
          lng: p.lng,
          riskScore: liveScore,
          timestamp: p.timestamp ?? DateTime.now(),
        );
      }).toList();
    } catch (_) {
      _manualOverrideActive = false;
      return points;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final compact = width < 920 || isAndroidUi;

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: mapController,
            options: const MapOptions(
              initialCenter: LatLng(19.076, 72.8777),
              initialZoom: 11,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              CircleLayer(
                circles: riskPoints
                    .map(
                      (p) => CircleMarker(
                        point: LatLng(p.lat, p.lng),
                        radius: 7 + (p.riskScore * 7),
                        color: riskColor(p.riskScore).withValues(alpha: 0.7),
                        borderStrokeWidth: 1.5,
                        borderColor: Colors.black45,
                      ),
                    )
                    .toList(),
              ),
              if (showSafeZones)
                CircleLayer(
                  circles: safeZones
                      .where((z) => z.active)
                      .map(
                        (z) => CircleMarker(
                          point: LatLng(z.lat, z.lng),
                          radius: 14,
                          color: Colors.green.withValues(alpha: 0.2),
                          borderStrokeWidth: 2,
                          borderColor: Colors.green,
                        ),
                      )
                      .toList(),
                ),
              if (showIncidents)
                MarkerLayer(
                  markers: incidents
                      .map(
                        (i) => Marker(
                          width: 30,
                          height: 30,
                          point: LatLng(i.lat, i.lng),
                          child: const Icon(
                            Icons.history_toggle_off_rounded,
                            color: Color(0xFFE53E3E),
                            size: 20,
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
        Positioned(
          top: compact ? 12 : 16,
          left: compact ? 12 : 16,
          child: _overlayPanel(
            context: context,
            title: 'Layers',
            compact: compact,
            collapsed: _layersCollapsed,
            onToggle: () => setState(() => _layersCollapsed = !_layersCollapsed),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: compact ? 170 : 220,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Safe Zones'),
                    value: showSafeZones,
                    onChanged: (v) => setState(() => showSafeZones = v),
                  ),
                ),
                SizedBox(
                  width: compact ? 170 : 220,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Historical Incidents'),
                    value: showIncidents,
                    onChanged: (v) => setState(() => showIncidents = v),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: compact ? null : 16,
          left: compact ? 12 : null,
          top: compact ? null : 16,
          bottom: compact ? 12 : null,
          child: _overlayPanel(
            context: context,
            title: 'Map Summary',
            compact: compact,
            collapsed: _summaryCollapsed,
            onToggle: () =>
                setState(() => _summaryCollapsed = !_summaryCollapsed),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Risk points: ${riskPoints.length}'),
                Text(
                  'Safe zones: ${safeZones.where((e) => e.active).length}',
                ),
                Text('Incidents: ${incidents.length}'),
                if (_manualOverrideActive) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Manual override active',
                    style: TextStyle(
                      color: Color(0xFFC53030),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_isLoading && riskPoints.isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.75),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _overlayPanel({
    required BuildContext context,
    required String title,
    required bool compact,
    required bool collapsed,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.82),
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggle,
                  icon: Icon(
                    collapsed
                        ? Icons.unfold_more_rounded
                        : Icons.unfold_less_rounded,
                    size: 18,
                  ),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                ),
              ],
            ),
            if (!collapsed) ...[
              const SizedBox(height: 4),
              child,
            ],
          ],
        ),
      ),
    );
  }
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
