import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/settings/citizen_preferences_scope.dart';
import '../../core/settings/citizen_strings.dart';
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
  static const Duration _autoRefreshInterval = Duration(seconds: 20);
  Timer? _autoRefreshTimer;
  bool _loading = true;
  String? _errorMessage;
  List<SafeZone> _zones = <SafeZone>[];
  bool _usingCachedZones = false;
  DateTime? _lastUpdatedAt;
  Position? _userLocation;
  bool _loadingLocation = false;
  String? _locationError;
  bool _isAutoRefreshing = false;

  String _languageCode(BuildContext context) {
    return CitizenPreferencesScope.maybeOf(context)?.languageCode ?? 'en';
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpSafeZonesApi();
    _locationProvider = widget.userLocationProvider ?? _defaultLocationProvider;
    _cache = widget.cache ?? SharedPrefsSafeZonesCache();
    _loadSafeZones();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (Timer _) {
      _autoRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  bool _isDataSaverEnabled() {
    return CitizenPreferencesScope.maybeOf(context)?.dataSaverEnabled ?? false;
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
      final String languageCode = _languageCode(context);
      setState(
        () => _locationError = CitizenStrings.tr(
          'safezones_location_fetch_failed',
          languageCode,
        ),
      );
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
    } catch (e) {
      debugPrint('Safe zones fetch failed (${_api.runtimeType}): $e');
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
        final String languageCode = _languageCode(context);
        setState(
          () => _errorMessage = CitizenStrings.tr(
            'safezones_load_failed',
            languageCode,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _autoRefresh() async {
    if (!mounted || _loading || _isAutoRefreshing) return;
    if (_isDataSaverEnabled()) return;
    _isAutoRefreshing = true;
    try {
      await _loadSafeZones();
    } finally {
      _isAutoRefreshing = false;
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
    final String languageCode = _languageCode(context);
    return CitizenStrings.tr('safezones_area_unavailable', languageCode);
  }

  String _pincodeLabel(SafeZone zone) {
    final String? explicit = zone.pincode?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final AreaAnchor? anchor = _nearestAnchor(zone);
    return anchor?.pincode ?? '--';
  }

  String _updatedAgo(DateTime? timestamp, String languageCode) {
    if (timestamp == null) {
      return CitizenStrings.tr('time_unknown', languageCode);
    }
    return CitizenStrings.relativeTimeFromNow(
      timestamp.toLocal(),
      languageCode,
    );
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

  Future<void> _openRouteToZone(SafeZone zone) async {
    final Position? user = _userLocation;
    final String languageCode = _languageCode(context);
    if (user == null) return;
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${user.latitude},${user.longitude}'
      '&destination=${zone.lat},${zone.lng}'
      '&travelmode=walking',
    );
    final bool launched = await launchUrl(uri);
    if (!mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          CitizenStrings.tr('safezones_route_open_failed', languageCode),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String languageCode = _languageCode(context);
    if (_loading && _zones.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _zones.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSafeZones,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          children: <Widget>[
            Card(
              key: const Key('safe-zones-unavailable-card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.cloud_off, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            CitizenStrings.tr(
                              'safezones_unavailable_title',
                              languageCode,
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(_errorMessage!),
                    const SizedBox(height: 8),
                    Text(
                      CitizenStrings.tr(
                        'safezones_unavailable_help',
                        languageCode,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('safe-zones-retry'),
                      onPressed: _loadSafeZones,
                      icon: const Icon(Icons.refresh),
                      label: Text(CitizenStrings.tr('retry', languageCode)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CitizenStrings.tr('safezones_retry_hint', languageCode),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_zones.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSafeZones,
        child: ListView(
          children: <Widget>[
            SizedBox(height: 160),
            Center(
              child: Text(CitizenStrings.tr('safezones_empty', languageCode)),
            ),
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
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double mapHeight = screenHeight < 760 ? 200 : 250;

    return RefreshIndicator(
      onRefresh: _loadSafeZones,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: <Widget>[
          if (_usingCachedZones)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CitizenStrings.tr('safezones_offline_banner', languageCode),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          if (_usingCachedZones) const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      FilledButton.icon(
                        key: const Key('safe-zones-location-btn'),
                        onPressed: _loadingLocation ? null : _fetchUserLocation,
                        icon: _loadingLocation
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          _loadingLocation
                              ? CitizenStrings.tr(
                                  'safezones_locating',
                                  languageCode,
                                )
                              : CitizenStrings.tr(
                                  'safezones_use_location',
                                  languageCode,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _locationError ??
                              (_userLocation == null
                                  ? CitizenStrings.tr(
                                      'safezones_distance_hidden',
                                      languageCode,
                                    )
                                  : CitizenStrings.tr(
                                      'safezones_distance_shown',
                                      languageCode,
                                    )),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CitizenStrings.trf(
                        'safezones_last_updated',
                        languageCode,
                        <String, String>{
                          'ago': _updatedAgo(_lastUpdatedAt, languageCode),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (nearest != null && nearestKm != null) ...<Widget>[
            const SizedBox(height: 10),
            Card(
              key: const Key('safe-zones-nearest-route-card'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      CitizenStrings.trf(
                        'safezones_nearest',
                        languageCode,
                        <String, String>{'zoneId': nearest.zoneId},
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CitizenStrings.trf(
                        'safezones_distance_eta',
                        languageCode,
                        <String, String>{
                          'km': nearestKm.toStringAsFixed(1),
                          'eta': _etaMinutes(nearestKm).toString(),
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CitizenStrings.tr('safezones_route_tip', languageCode),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('safe-zones-open-route'),
                      onPressed: () => _openRouteToZone(nearest),
                      icon: const Icon(Icons.route),
                      label: Text(
                        CitizenStrings.tr('safezones_open_route', languageCode),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Card(
            child: SizedBox(
              height: mapHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
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
                              child: const Icon(
                                Icons.shield,
                                color: Colors.green,
                              ),
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
                              LatLng(
                                _userLocation!.latitude,
                                _userLocation!.longitude,
                              ),
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
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              title: Text(
                CitizenStrings.trf(
                  'safezones_active_count',
                  languageCode,
                  <String, String>{'count': orderedZones.length.toString()},
                ),
              ),
              trailing: IconButton(
                key: const Key('safe-zones-refresh'),
                onPressed: _loadSafeZones,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ...orderedZones.map((SafeZone zone) {
            final double? km = _distanceKm(zone);
            return Card(
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: ListTile(
                title: Text(
                  zone.zoneId.isEmpty
                      ? CitizenStrings.tr(
                          'safezones_unnamed_zone',
                          languageCode,
                        )
                      : zone.zoneId,
                ),
                subtitle: Text(
                  '${CitizenStrings.trf('safezones_coords', languageCode, <String, String>{'lat': zone.lat.toStringAsFixed(4), 'lng': zone.lng.toStringAsFixed(4)})}\n'
                  '${CitizenStrings.trf('safezones_area_pincode', languageCode, <String, String>{'area': _areaLabel(zone), 'pincode': _pincodeLabel(zone)})}\n'
                  '${CitizenStrings.trf('safezones_source_confidence', languageCode, <String, String>{'source': zone.source, 'confidence': zone.confidence.toString()})}\n'
                  '${CitizenStrings.trf('alerts_updated', languageCode, <String, String>{'ago': _updatedAgo(zone.lastVerified, languageCode)})}',
                ),
                trailing: Text(
                  km == null ? '--' : '${km.toStringAsFixed(1)} km',
                  key: const Key('safe-zone-distance-label'),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
