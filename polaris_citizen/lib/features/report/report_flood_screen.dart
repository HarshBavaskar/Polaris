import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../safe_zones/safe_zone.dart';
import '../safe_zones/safe_zones_api.dart';
import 'report_api.dart';

class ReportFloodScreen extends StatefulWidget {
  final CitizenReportApi? api;
  final ImagePicker? imagePicker;
  final SafeZonesApi? safeZonesApi;

  const ReportFloodScreen({
    super.key,
    this.api,
    this.imagePicker,
    this.safeZonesApi,
  });

  @override
  State<ReportFloodScreen> createState() => _ReportFloodScreenState();
}

class _ReportFloodScreenState extends State<ReportFloodScreen> {
  final TextEditingController _zoneIdController = TextEditingController();
  final TextEditingController _localityController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  static const List<String> _levels = <String>[
    'LOW',
    'MEDIUM',
    'HIGH',
    'SEVERE',
  ];
  static const List<String> _cities = <String>[
    'Mumbai',
    'Thane',
    'Navi Mumbai',
    'Kalyan-Dombivli',
    'Mira-Bhayandar',
    'Palghar',
  ];
  late final CitizenReportApi _api;
  late final ImagePicker _picker;
  late final SafeZonesApi _safeZonesApi;

  String _selectedLevel = 'MEDIUM';
  List<SafeZone> _safeZoneOptions = <SafeZone>[];
  String? _selectedZoneId;
  String _zoneMode = 'SUGGESTED';
  String _selectedCity = _cities.first;
  bool _loadingZones = true;
  String? _zoneLoadError;
  XFile? _selectedImage;
  bool _sendingLevel = false;
  bool _sendingPhoto = false;
  bool _findingNearest = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpCitizenReportApi();
    _picker = widget.imagePicker ?? ImagePicker();
    _safeZonesApi = widget.safeZonesApi ?? HttpSafeZonesApi();
    _loadZoneOptions();
  }

  @override
  void dispose() {
    _zoneIdController.dispose();
    _localityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _normalizedZoneId() {
    if (_zoneMode == 'SUGGESTED') {
      return (_selectedZoneId ?? '').trim();
    }
    if (_zoneMode == 'AREA_PINCODE') {
      final String city = _selectedCity.trim().toUpperCase().replaceAll(
        ' ',
        '_',
      );
      final String locality = _localityController.text
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'\s+'), '_');
      final String pincode = _pincodeController.text.trim();
      if (locality.isNotEmpty) {
        return '$city-$locality-$pincode';
      }
      return '$city-$pincode';
    }
    return _zoneIdController.text.trim();
  }

  String _zoneIdForOption(SafeZone zone) {
    final String direct = zone.zoneId.trim();
    if (direct.isNotEmpty) return direct;
    return 'LAT${zone.lat.toStringAsFixed(4)}_LNG${zone.lng.toStringAsFixed(4)}';
  }

  Future<void> _loadZoneOptions() async {
    setState(() {
      _loadingZones = true;
      _zoneLoadError = null;
    });

    try {
      final List<SafeZone> zones = await _safeZonesApi.fetchSafeZones();
      if (!mounted) return;

      final List<SafeZone> valid = zones
          .where((SafeZone z) => z.active)
          .toList();
      String? nextSelection = _selectedZoneId;
      if (valid.isNotEmpty) {
        final List<String> ids = valid.map(_zoneIdForOption).toList();
        if (nextSelection == null || !ids.contains(nextSelection)) {
          nextSelection = ids.first;
        }
      } else {
        nextSelection = null;
        if (_zoneMode == 'SUGGESTED') {
          _zoneMode = 'AREA_PINCODE';
        }
      }

      setState(() {
        _safeZoneOptions = valid;
        _selectedZoneId = nextSelection;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _zoneLoadError = 'Could not load zone suggestions.');
    } finally {
      if (mounted) {
        setState(() => _loadingZones = false);
      }
    }
  }

  bool _validateZoneId() {
    if (_zoneMode == 'SUGGESTED' && (_selectedZoneId ?? '').trim().isEmpty) {
      _showMessage(
        'No suggested zone available. Switch to Area/Pincode or Custom.',
      );
      return false;
    }

    if (_zoneMode == 'AREA_PINCODE') {
      final String pin = _pincodeController.text.trim();
      if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
        _showMessage('Please enter a valid 6-digit pincode.');
        return false;
      }
    }

    if (_zoneMode == 'CUSTOM' && _zoneIdController.text.trim().isEmpty) {
      _showMessage('Please select a zone or enter a custom zone ID.');
      return false;
    }
    return true;
  }

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const double earthRadius = 6371000;
    final double dLat = _toRad(lat2 - lat1);
    final double dLng = _toRad(lng2 - lng1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRad(double value) => value * (math.pi / 180);

  Future<void> _useGpsNearestZone() async {
    if (_safeZoneOptions.isEmpty) {
      _showMessage('No active safe zones available for nearest lookup.');
      return;
    }

    setState(() => _findingNearest = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Location service is disabled on this device.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission denied.');
        return;
      }

      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      SafeZone nearest = _safeZoneOptions.first;
      double bestDistance = _distanceMeters(
        lat1: pos.latitude,
        lng1: pos.longitude,
        lat2: nearest.lat,
        lng2: nearest.lng,
      );

      for (final SafeZone zone in _safeZoneOptions.skip(1)) {
        final double d = _distanceMeters(
          lat1: pos.latitude,
          lng1: pos.longitude,
          lat2: zone.lat,
          lng2: zone.lng,
        );
        if (d < bestDistance) {
          bestDistance = d;
          nearest = zone;
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedZoneId = _zoneIdForOption(nearest);
        _zoneMode = 'SUGGESTED';
      });
      _showMessage(
        'Nearest safe zone selected: ${_selectedZoneId!} (${bestDistance.toStringAsFixed(0)} m)',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to determine current location.');
    } finally {
      if (mounted) setState(() => _findingNearest = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (image == null || !mounted) return;
      setState(() => _selectedImage = image);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to access camera/gallery.');
    }
  }

  Future<void> _submitWaterLevel() async {
    if (!_validateZoneId()) return;
    setState(() => _sendingLevel = true);
    try {
      final String message = await _api.submitWaterLevel(
        zoneId: _normalizedZoneId(),
        level: _selectedLevel,
      );
      if (!mounted) return;
      _showMessage(message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to submit water level.');
    } finally {
      if (mounted) setState(() => _sendingLevel = false);
    }
  }

  Future<void> _submitFloodPhoto() async {
    if (!_validateZoneId()) return;
    if (_selectedImage == null) {
      _showMessage('Please capture or choose a flood photo.');
      return;
    }

    setState(() => _sendingPhoto = true);
    try {
      final String message = await _api.submitFloodPhoto(
        zoneId: _normalizedZoneId(),
        image: _selectedImage!,
      );
      if (!mounted) return;
      _showMessage(message);
      setState(() => _selectedImage = null);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to submit flood photo.');
    } finally {
      if (mounted) setState(() => _sendingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text(
                      'Location Zone',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('zone-refresh-button'),
                      onPressed: _loadingZones ? null : _loadZoneOptions,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh zones',
                    ),
                  ],
                ),
                if (_loadingZones) ...<Widget>[
                  const SizedBox(height: 8),
                  const Row(
                    children: <Widget>[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading nearby zone suggestions...'),
                    ],
                  ),
                ] else ...<Widget>[
                  if (_zoneLoadError != null) ...<Widget>[
                    Text(_zoneLoadError!),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        key: const Key('zone-mode-suggested'),
                        label: const Text('Suggested Safe Zone'),
                        selected: _zoneMode == 'SUGGESTED',
                        onSelected: _safeZoneOptions.isEmpty
                            ? null
                            : (_) => setState(() => _zoneMode = 'SUGGESTED'),
                      ),
                      ChoiceChip(
                        key: const Key('zone-mode-area-pincode'),
                        label: const Text('Area + Pincode'),
                        selected: _zoneMode == 'AREA_PINCODE',
                        onSelected: (_) =>
                            setState(() => _zoneMode = 'AREA_PINCODE'),
                      ),
                      ChoiceChip(
                        key: const Key('zone-mode-custom'),
                        label: const Text('Custom ID'),
                        selected: _zoneMode == 'CUSTOM',
                        onSelected: (_) => setState(() => _zoneMode = 'CUSTOM'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_safeZoneOptions.isNotEmpty) ...<Widget>[
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Suggested Zone ID',
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('zone-id-dropdown'),
                          isExpanded: true,
                          value: _selectedZoneId,
                          items: _safeZoneOptions.map((SafeZone zone) {
                            final String zoneId = _zoneIdForOption(zone);
                            return DropdownMenuItem<String>(
                              value: zoneId,
                              child: Text(zoneId),
                            );
                          }).toList(),
                          onChanged: _zoneMode != 'SUGGESTED'
                              ? null
                              : (String? value) {
                                  setState(() => _selectedZoneId = value);
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('zone-gps-nearest'),
                      onPressed: _findingNearest ? null : _useGpsNearestZone,
                      icon: _findingNearest
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(
                        _findingNearest
                            ? 'Finding nearest safe zone...'
                            : 'Use GPS Nearest Safe Zone',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...<Widget>[
                    const Text(
                      'No suggested zone IDs available right now. Use custom zone ID.',
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_zoneMode == 'AREA_PINCODE') ...<Widget>[
                    DropdownButtonFormField<String>(
                      key: const Key('area-city-dropdown'),
                      initialValue: _selectedCity,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'City / District',
                      ),
                      items: _cities.map((String city) {
                        return DropdownMenuItem<String>(
                          value: city,
                          child: Text(city),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        if (value == null) return;
                        setState(() => _selectedCity = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('area-locality-input'),
                      controller: _localityController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Area / Locality (optional)',
                        hintText: 'Example: Thane West',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('area-pincode-input'),
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Pincode',
                        hintText: '6-digit pincode',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generated zone ID: ${_normalizedZoneId().isEmpty ? '--' : _normalizedZoneId()}',
                    ),
                  ],
                  if (_zoneMode == 'CUSTOM')
                    TextField(
                      key: const Key('custom-zone-id-input'),
                      controller: _zoneIdController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Custom Zone ID',
                        hintText: 'Example: WARD-12 or STREET-03',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Flood Photo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      key: const Key('pick-photo-camera'),
                      onPressed: _sendingPhoto
                          ? null
                          : () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('pick-photo-gallery'),
                      onPressed: _sendingPhoto
                          ? null
                          : () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
                if (_selectedImage != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('Selected: ${_selectedImage!.name}'),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('submit-photo-button'),
                  onPressed: _sendingPhoto ? null : _submitFloodPhoto,
                  icon: _sendingPhoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _sendingPhoto ? 'Submitting...' : 'Submit Flood Photo',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Flooding Level',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _levels.map((String level) {
                    return ChoiceChip(
                      key: Key('level-$level'),
                      label: Text(level),
                      selected: _selectedLevel == level,
                      onSelected: (_) {
                        setState(() => _selectedLevel = level);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('submit-level-button'),
                  onPressed: _sendingLevel ? null : _submitWaterLevel,
                  icon: _sendingLevel
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _sendingLevel ? 'Submitting...' : 'Submit Water Level',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
