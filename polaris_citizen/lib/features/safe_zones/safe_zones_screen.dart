import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/locations/priority_area_anchors.dart';
import 'safe_zone.dart';
import 'safe_zones_api.dart';
import 'safe_zones_cache.dart';

typedef UserLocationProvider = Future<Position> Function();

class SafeZonesScreen extends StatefulWidget {
  final SafeZonesApi? api;
  final UserLocationProvider? userLocationProvider;
  final SafeZonesCache? cache;

  const SafeZonesScreen({
    super.key,
    this.api,
    this.userLocationProvider,
    this.cache,
  });

  @override
  State<SafeZonesScreen> createState() => _SafeZonesScreenState();
}

class _SafeZonesScreenState extends State<SafeZonesScreen> {
  late final SafeZonesApi _api;
  late final UserLocationProvider _locationProvider;
  late final SafeZonesCache _cache;
  bool _loading = true;
  String? _errorMessage;
  List<SafeZone> _zones = <SafeZone>[];
  bool _usingCachedZones = false;
  DateTime? _lastUpdatedAt;
  Position? _userLocation;
  bool _loadingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpSafeZonesApi();
    _locationProvider = widget.userLocationProvider ?? _defaultLocationProvider;
    _cache = widget.cache ?? SharedPrefsSafeZonesCache();
    _loadSafeZones();
  }

  Future<Position> _defaultLocationProvider() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location service disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _fetchUserLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      final Position p = await _locationProvider();
      if (!mounted) return;
      setState(() => _userLocation = p);
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationError = 'Unable to fetch current location.');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _loadSafeZones() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _usingCachedZones = false;
    });

    try {
      final List<SafeZone> zones = await _api.fetchSafeZones();
      await _cache.saveZones(zones);
      final DateTime? updatedAt = await _cache.lastUpdatedAt();
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _usingCachedZones = false;
        _lastUpdatedAt = updatedAt;
      });
    } catch (_) {
      final List<SafeZone> cached = await _cache.loadZones();
      final DateTime? updatedAt = await _cache.lastUpdatedAt();
      if (!mounted) return;
      if (cached.isNotEmpty) {
        setState(() {
          _zones = cached;
          _usingCachedZones = true;
          _errorMessage = null;
          _lastUpdatedAt = updatedAt;
        });
      } else {
        setState(() => _errorMessage = 'Failed to load safe zones.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _distanceKm(SafeZone zone) {
    final Position? user = _userLocation;
    if (user == null) return null;
    final double meters = Geolocator.distanceBetween(
      user.latitude,
      user.longitude,
      zone.lat,
      zone.lng,
    );
    return meters / 1000;
  }

  AreaAnchor? _nearestAnchor(SafeZone zone) {
    AreaAnchor? best;
    double bestMeters = double.infinity;
    for (final AreaAnchor a in priorityAreaAnchors) {
      final double d = Geolocator.distanceBetween(
        zone.lat,
        zone.lng,
        a.lat,
        a.lng,
      );
      if (d < bestMeters) {
        bestMeters = d;
        best = a;
      }
    }

    if (best == null) return null;
    if (bestMeters > 25000) return null;
    return best;
  }

  String _areaLabel(SafeZone zone) {
    final String? explicit = zone.area?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final AreaAnchor? anchor = _nearestAnchor(zone);
    if (anchor != null) return '${anchor.area}, ${anchor.city}';
    return 'Area unavailable';
  }

  String _pincodeLabel(SafeZone zone) {
    final String? explicit = zone.pincode?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final AreaAnchor? anchor = _nearestAnchor(zone);
    return anchor?.pincode ?? '--';
  }

  String _updatedAgo(DateTime? timestamp) {
    if (timestamp == null) return 'Updated: unknown';
    final Duration diff = DateTime.now().difference(timestamp.toLocal());
    if (diff.isNegative || diff.inSeconds < 60) return 'Updated: just now';
    if (diff.inMinutes < 60) return 'Updated: ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Updated: ${diff.inHours} hr ago';
    return 'Updated: ${diff.inDays} day(s) ago';
  }

  SafeZone? _nearestZone(List<SafeZone> zones) {
    final Position? user = _userLocation;
    if (user == null || zones.isEmpty) return null;
    SafeZone nearest = zones.first;
    double best = Geolocator.distanceBetween(
      user.latitude,
      user.longitude,
      nearest.lat,
      nearest.lng,
    );
    for (final SafeZone zone in zones.skip(1)) {
      final double d = Geolocator.distanceBetween(
        user.latitude,
        user.longitude,
        zone.lat,
        zone.lng,
      );
      if (d < best) {
        best = d;
        nearest = zone;
      }
    }
    return nearest;
  }

  int _etaMinutes(double km) {
    final double walkingKmph = 4.5;
    final double mins = (km / walkingKmph) * 60;
    return mins.ceil().clamp(1, 999);
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

    final List<SafeZone> orderedZones = List<SafeZone>.from(_zones);
    if (_userLocation != null) {
      orderedZones.sort((SafeZone a, SafeZone b) {
        final double da = _distanceKm(a) ?? double.infinity;
        final double db = _distanceKm(b) ?? double.infinity;
        return da.compareTo(db);
      });
    }

    final LatLng center = _userLocation != null
        ? LatLng(_userLocation!.latitude, _userLocation!.longitude)
        : LatLng(orderedZones.first.lat, orderedZones.first.lng);
    final SafeZone? nearest = _nearestZone(orderedZones);
    final double? nearestKm = nearest == null ? null : _distanceKm(nearest);

    return Column(
      children: <Widget>[
        if (_usingCachedZones)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Offline mode: showing last saved safe zones.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: <Widget>[
              FilledButton.icon(
                key: const Key('safe-zones-location-btn'),
                onPressed: _loadingLocation ? null : _fetchUserLocation,
                icon: _loadingLocation
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _loadingLocation ? 'Locating...' : 'Use My Location',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _locationError ??
                      (_userLocation == null
                          ? 'Distance hidden until location is enabled.'
                          : 'Distance now shown from your location.'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Safe zones last updated: ${_updatedAgo(_lastUpdatedAt).replaceFirst('Updated: ', '')}',
            ),
          ),
        ),
        if (nearest != null && nearestKm != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              key: const Key('safe-zones-nearest-route-card'),
              child: ListTile(
                title: Text('Nearest safe zone: ${nearest.zoneId}'),
                subtitle: Text(
                  'Distance: ${nearestKm.toStringAsFixed(1)} km | ETA: ~${_etaMinutes(nearestKm)} min',
                ),
              ),
            ),
          ),
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
                circles: orderedZones
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
                markers: orderedZones
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
              if (_userLocation != null)
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      width: 44,
                      height: 44,
                      point: LatLng(
                        _userLocation!.latitude,
                        _userLocation!.longitude,
                      ),
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              if (_userLocation != null && nearest != null)
                PolylineLayer(
                  polylines: <Polyline>[
                    Polyline(
                      points: <LatLng>[
                        LatLng(_userLocation!.latitude, _userLocation!.longitude),
                        LatLng(nearest.lat, nearest.lng),
                      ],
                      color: Colors.blue,
                      strokeWidth: 3,
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: RefreshIndicator(
            onRefresh: _loadSafeZones,
            child: ListView.builder(
              itemCount: orderedZones.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return ListTile(
                    title: Text('Active safe zones: ${orderedZones.length}'),
                    trailing: IconButton(
                      key: const Key('safe-zones-refresh'),
                      onPressed: _loadSafeZones,
                      icon: const Icon(Icons.refresh),
                    ),
                  );
                }

                final SafeZone zone = orderedZones[index - 1];
                final double? km = _distanceKm(zone);
                return Card(
                  child: ListTile(
                    title: Text(
                      zone.zoneId.isEmpty ? 'Unnamed Zone' : zone.zoneId,
                    ),
                    subtitle: Text(
                      'Lat ${zone.lat.toStringAsFixed(4)}, Lng ${zone.lng.toStringAsFixed(4)}'
                      '\nArea: ${_areaLabel(zone)} | Pincode: ${_pincodeLabel(zone)}'
                      '\nSource: ${zone.source} | Confidence: ${zone.confidence}'
                      '\n${_updatedAgo(zone.lastVerified)}',
                    ),
                    trailing: Text(
                      km == null ? '--' : '${km.toStringAsFixed(1)} km',
                      key: const Key('safe-zone-distance-label'),
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
