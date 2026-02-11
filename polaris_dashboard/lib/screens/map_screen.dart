import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api_service.dart';
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

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    loadAll();
    refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => loadAll());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadAll() async {
    try {
      final rp = await ApiService.fetchLiveRiskPoints();
      final sz = await ApiService.fetchSafeZones();
      final hi = await ApiService.fetchHistoricalIncidents();
      final uniqueRiskPoints = _latestRiskPerExactLocation(rp);

      if (!mounted) return;

      setState(() {
        riskPoints = uniqueRiskPoints;
        safeZones = sz;
        incidents = hi;
      });

      if (!_hasAutoCentered && riskPoints.isNotEmpty) {
        final highest = riskPoints.reduce((a, b) => a.riskScore > b.riskScore ? a : b);
        mapController.move(LatLng(highest.lat, highest.lng), 12);
        _hasAutoCentered = true;
      }
    } catch (_) {}
  }

  Color riskColor(double riskScore) {
    if (riskScore >= 0.8) return const Color(0xFFE53E3E);
    if (riskScore >= 0.65) return const Color(0xFFDD6B20);
    if (riskScore >= 0.4) return const Color(0xFFD69E2E);
    return const Color(0xFF2F855A);
  }

  @override
  Widget build(BuildContext context) {
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
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
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
          top: 16,
          left: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Layers',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 220,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Safe Zones'),
                      value: showSafeZones,
                      onChanged: (v) => setState(() => showSafeZones = v),
                    ),
                  ),
                  SizedBox(
                    width: 220,
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
        ),
        Positioned(
          right: 16,
          top: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map Summary',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text('Risk points: ${riskPoints.length}'),
                  Text('Safe zones: ${safeZones.where((e) => e.active).length}'),
                  Text('Incidents: ${incidents.length}'),
                ],
              ),
            ),
          ),
        ),
      ],
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
