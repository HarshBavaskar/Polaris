import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api_service.dart';
import '../core/models/risk_point.dart';
import '../core/models/safe_zone.dart';
import '../core/models/historical_incident.dart';

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

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    loadAll();
    refreshTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => loadAll());
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

      setState(() {
        riskPoints = rp;
        safeZones = sz;
        incidents = hi;
      });

      if (riskPoints.isNotEmpty) {
        final highest = riskPoints
            .reduce((a, b) => a.riskScore > b.riskScore ? a : b);
        mapController.move(
          LatLng(highest.lat, highest.lng),
          12,
        );
      }
    } catch (_) {}
  }

  Color riskColor(double riskScore) {
    // Keep thresholds aligned with backend risk_level() in app/utils/risk_logic.py
    if (riskScore >= 0.8) return const Color.fromARGB(255, 255, 17, 0); // IMMINENT
    if (riskScore >= 0.65) return const Color.fromARGB(255, 255, 153, 0); // WARNING
    if (riskScore >= 0.4) return const Color.fromARGB(255, 255, 230, 0); // WATCH
    return const Color.fromARGB(255, 0, 255, 0); // SAFE
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
  child: Stack(
    children: [
      Positioned.fill(
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: const LatLng(19.076, 72.8777),
            initialZoom: 11,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: const ["a", "b", "c"],
            ),

            // Risk points
            CircleLayer(
              circles: riskPoints.isEmpty
                  ? <CircleMarker<Object>>[]
                  : [
                      () {
                        final p = riskPoints.first; // latest only
                        return CircleMarker(
                          point: LatLng(p.lat, p.lng),
                          radius: 10,
                          color: riskColor(p.riskScore).withValues(alpha: 0.7),
                          borderStrokeWidth: 1,
                          borderColor: Colors.black54,
                        );
                      }(),
                    ],
            ),

            // Safe zones
            if (showSafeZones)
              CircleLayer(
                circles: safeZones
                    .where((z) => z.active)
                    .map(
                      (z) => CircleMarker(
                        point: LatLng(z.lat, z.lng),
                        radius: 14,
                        color: Colors.green.withValues(alpha: 0.25),
                        borderStrokeWidth: 2,
                        borderColor: Colors.green,
                      ),
                    )
                    .toList(),
              ),

            // Historical incidents
            if (showIncidents)
              MarkerLayer(
                markers: incidents
                    .map(
                      (i) => Marker(
                        width: 30,
                        height: 30,
                        point: LatLng(i.lat, i.lng),
                        child: const Icon(
                          Icons.history,
                          color: Color.fromARGB(255, 255, 0, 0),
                          size: 20,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),

      // Layer toggles
      Positioned(
        top: 16,
        right: 16,
        child: Card(
          child: SizedBox(width: 220,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text("Safe Zones"),
                value: showSafeZones,
                onChanged: (v) => setState(() => showSafeZones = v),
              ),
              SwitchListTile(
                title: const Text("History"),
                value: showIncidents,
                onChanged: (v) => setState(() => showIncidents = v),
              ),
            ],
          ),
        ),
        ),
      ),
    ],
  ),
  );

  }
}
