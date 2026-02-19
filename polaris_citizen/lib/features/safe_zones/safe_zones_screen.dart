import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'safe_zone.dart';
import 'safe_zones_api.dart';

class SafeZonesScreen extends StatefulWidget {
  final SafeZonesApi? api;

  const SafeZonesScreen({super.key, this.api});

  @override
  State<SafeZonesScreen> createState() => _SafeZonesScreenState();
}

class _SafeZonesScreenState extends State<SafeZonesScreen> {
  late final SafeZonesApi _api;
  bool _loading = true;
  String? _errorMessage;
  List<SafeZone> _zones = <SafeZone>[];

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpSafeZonesApi();
    _loadSafeZones();
  }

  Future<void> _loadSafeZones() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final List<SafeZone> zones = await _api.fetchSafeZones();
      if (!mounted) return;
      setState(() => _zones = zones);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to load safe zones.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _zones.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _zones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_errorMessage!),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('safe-zones-retry'),
                onPressed: _loadSafeZones,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_zones.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSafeZones,
        child: ListView(
          children: const <Widget>[
            SizedBox(height: 160),
            Center(child: Text('No active safe zones available right now.')),
          ],
        ),
      );
    }

    final LatLng center = LatLng(_zones.first.lat, _zones.first.lng);

    return Column(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: <Widget>[
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const <String>['a', 'b', 'c', 'd'],
              ),
              CircleLayer(
                circles: _zones
                    .map(
                      (SafeZone zone) => CircleMarker(
                        point: LatLng(zone.lat, zone.lng),
                        radius: 12,
                        color: Colors.green.withValues(alpha: 0.22),
                        borderColor: Colors.green.shade700,
                        borderStrokeWidth: 2,
                      ),
                    )
                    .toList(),
              ),
              MarkerLayer(
                markers: _zones
                    .map(
                      (SafeZone zone) => Marker(
                        width: 36,
                        height: 36,
                        point: LatLng(zone.lat, zone.lng),
                        child: const Icon(Icons.shield, color: Colors.green),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: RefreshIndicator(
            onRefresh: _loadSafeZones,
            child: ListView.builder(
              itemCount: _zones.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return ListTile(
                    title: Text('Active safe zones: ${_zones.length}'),
                    trailing: IconButton(
                      key: const Key('safe-zones-refresh'),
                      onPressed: _loadSafeZones,
                      icon: const Icon(Icons.refresh),
                    ),
                  );
                }

                final SafeZone zone = _zones[index - 1];
                return Card(
                  child: ListTile(
                    title: Text(
                      zone.zoneId.isEmpty ? 'Unnamed Zone' : zone.zoneId,
                    ),
                    subtitle: Text(
                      'Lat ${zone.lat.toStringAsFixed(4)}, Lng ${zone.lng.toStringAsFixed(4)}'
                      '\nSource: ${zone.source} | Confidence: ${zone.confidence}',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
