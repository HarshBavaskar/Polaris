import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/locations/priority_area_anchors.dart';
import '../../core/settings/citizen_preferences_scope.dart';
import '../../core/settings/citizen_strings.dart';
import 'report_api.dart';
import 'report_history.dart';
import 'report_offline_queue.dart';
import 'report_sync_service.dart';

typedef CurrentPositionProvider = Future<Position> Function();

class ReportFloodScreen extends StatefulWidget {
  final CitizenReportApi? api;
  final ImagePicker? imagePicker;
  final ReportOfflineQueue? offlineQueue;
  final CitizenReportHistoryStore? historyStore;
  final CurrentPositionProvider? positionProvider;

  const ReportFloodScreen({
    super.key,
    this.api,
    this.imagePicker,
    this.offlineQueue,
    this.historyStore,
    this.positionProvider,
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
    'Palghar',
    'Other',
  ];

  static const Map<String, List<String>> _areaSuggestionsByCity =
      <String, List<String>>{
        'Mumbai': <String>[
          'Andheri',
          'Bandra',
          'Borivali',
          'Dadar',
          'Kurla',
          'Ghatkopar',
        ],
        'Thane': <String>[
          'Thane West',
          'Thane East',
          'Mumbra',
          'Kalyan',
          'Dombivli',
        ],
        'Navi Mumbai': <String>[
          'Vashi',
          'Nerul',
          'Belapur',
          'Airoli',
          'Ghansoli',
        ],
        'Palghar': <String>['Vasai', 'Virar', 'Nalasopara', 'Boisar'],
      };

  late final CitizenReportApi _api;
  late final ImagePicker _picker;
  late final ReportOfflineQueue _offlineQueue;
  late final CitizenReportHistoryStore _historyStore;
  late final CurrentPositionProvider _positionProvider;
  late final ReportSyncService _syncService;

  String _selectedLevel = 'MEDIUM';
  String _zoneMode = 'AREA_PINCODE';
  String _selectedCity = _cities.first;
  String? _selectedAreaSuggestion;
  XFile? _selectedImage;
  bool _sendingLevel = false;
  bool _sendingPhoto = false;
  bool _syncingPending = false;
  bool _locatingArea = false;
  int _pendingWaterLevelCount = 0;
  String _languageCodeValue = 'en';

  String get _languageCode => _languageCodeValue;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpCitizenReportApi();
    _picker = widget.imagePicker ?? ImagePicker();
    _offlineQueue = widget.offlineQueue ?? SharedPrefsReportOfflineQueue();
    _historyStore =
        widget.historyStore ?? SharedPrefsCitizenReportHistoryStore();
    _positionProvider = widget.positionProvider ?? _defaultPositionProvider;
    _syncService = ReportSyncService(
      api: _api,
      offlineQueue: _offlineQueue,
      historyStore: _historyStore,
    );
    _refreshPendingCount();
    _syncPendingWaterLevels(showEmptyMessage: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageCodeValue =
        CitizenPreferencesScope.maybeOf(context)?.languageCode ?? 'en';
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

  Future<Position> _defaultPositionProvider() async {
    final String languageCode = _languageCode;
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        CitizenStrings.tr('report_loc_service_disabled', languageCode),
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
        CitizenStrings.tr('report_loc_permission_denied', languageCode),
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  List<String> _areaSuggestions() {
    return _areaSuggestionsByCity[_selectedCity] ?? const <String>[];
  }

  String _normalizedZoneId() {
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

  String _newReportId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _refreshPendingCount() async {
    final List<PendingWaterLevelReport> pending = await _offlineQueue
        .pendingWaterLevels();
    if (!mounted) return;
    setState(() => _pendingWaterLevelCount = pending.length);
  }

  Future<void> _syncPendingWaterLevels({bool showEmptyMessage = true}) async {
    final String languageCode = _languageCode;
    if (_syncingPending) return;
    setState(() => _syncingPending = true);
    try {
      final ReportSyncSummary summary = await _syncService
          .syncPendingWaterLevels();
      if (summary.synced == 0 && summary.failed == 0 && summary.pending == 0) {
        if (showEmptyMessage) {
          _showMessage(CitizenStrings.tr('report_sync_none', languageCode));
        }
        return;
      }
      await _refreshPendingCount();
      if (showEmptyMessage || summary.synced > 0 || summary.pending > 0) {
        _showMessage(
          CitizenStrings.trf(
            'report_sync_summary',
            languageCode,
            <String, String>{
              'synced': summary.synced.toString(),
              'failed': summary.failed.toString(),
              'pending': summary.pending.toString(),
            },
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingPending = false);
    }
  }

  bool _validateZoneId() {
    final String languageCode = _languageCode;
    if (_zoneMode == 'AREA_PINCODE') {
      final String pin = _pincodeController.text.trim();
      if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
        _showMessage(CitizenStrings.tr('report_invalid_pincode', languageCode));
        return false;
      }
    }

    if (_zoneMode == 'CUSTOM' && _zoneIdController.text.trim().isEmpty) {
      _showMessage(CitizenStrings.tr('report_enter_custom_zone', languageCode));
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

  Future<void> _useGpsAutoFillArea() async {
    final String languageCode = _languageCode;
    if (_locatingArea) return;
    setState(() => _locatingArea = true);
    try {
      final Position pos = await _positionProvider();
      AreaAnchor? nearest;
      double nearestDistance = double.infinity;
      for (final AreaAnchor anchor in priorityAreaAnchors) {
        final double d = _distanceMeters(
          lat1: pos.latitude,
          lng1: pos.longitude,
          lat2: anchor.lat,
          lng2: anchor.lng,
        );
        if (d < nearestDistance) {
          nearest = anchor;
          nearestDistance = d;
        }
      }

      if (!mounted) return;
      if (nearest != null && nearestDistance <= 35000) {
        setState(() {
          _zoneMode = 'AREA_PINCODE';
          _selectedCity = _cities.contains(nearest!.city)
              ? nearest.city
              : 'Other';
          _selectedAreaSuggestion = _areaSuggestions().contains(nearest.area)
              ? nearest.area
              : null;
          _localityController.text = nearest.area;
          _pincodeController.text = nearest.pincode;
        });
        _showMessage(
          CitizenStrings.trf(
            'report_detected_area',
            languageCode,
            <String, String>{
              'city': nearest.city,
              'area': nearest.area,
              'pincode': nearest.pincode,
            },
          ),
        );
      } else {
        final String lat = pos.latitude.toStringAsFixed(4);
        final String lng = pos.longitude.toStringAsFixed(4);
        setState(() {
          _zoneMode = 'CUSTOM';
          _zoneIdController.text = 'GPS-$lat-$lng';
        });
        _showMessage(
          CitizenStrings.tr('report_gps_custom_created', languageCode),
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        CitizenStrings.tr('report_unable_detect_location', languageCode),
      );
    } finally {
      if (mounted) setState(() => _locatingArea = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final String languageCode = _languageCode;
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
      _showMessage(
        CitizenStrings.tr('report_unable_access_camera_gallery', languageCode),
      );
    }
  }

  Future<void> _submitWaterLevel() async {
    final String languageCode = _languageCode;
    if (!_validateZoneId()) return;
    setState(() => _sendingLevel = true);
    final String zoneId = _normalizedZoneId();
    final String reportId = _newReportId('wl');
    final DateTime now = DateTime.now().toLocal();
    try {
      final String message = await _api.submitWaterLevel(
        zoneId: zoneId,
        level: _selectedLevel,
      );
      await _historyStore.upsertRecord(
        CitizenReportRecord(
          id: reportId,
          type: CitizenReportType.waterLevel,
          zoneId: zoneId,
          level: _selectedLevel,
          status: CitizenReportStatus.synced,
          createdAt: now,
          updatedAt: now,
          note: 'Submitted successfully',
        ),
      );
      if (!mounted) return;
      _showMessage(message);
    } on CitizenReportHttpException {
      await _historyStore.upsertRecord(
        CitizenReportRecord(
          id: reportId,
          type: CitizenReportType.waterLevel,
          zoneId: zoneId,
          level: _selectedLevel,
          status: CitizenReportStatus.failed,
          createdAt: now,
          updatedAt: DateTime.now().toLocal(),
          note: 'Submission failed at server',
        ),
      );
      if (!mounted) return;
      _showMessage(
        CitizenStrings.tr('report_submission_failed_water', languageCode),
      );
    } catch (_) {
      await _offlineQueue.enqueueWaterLevel(
        PendingWaterLevelReport(
          clientReportId: reportId,
          zoneId: zoneId,
          level: _selectedLevel,
          queuedAt: DateTime.now().toUtc(),
        ),
      );
      await _historyStore.upsertRecord(
        CitizenReportRecord(
          id: reportId,
          type: CitizenReportType.waterLevel,
          zoneId: zoneId,
          level: _selectedLevel,
          status: CitizenReportStatus.pendingOffline,
          createdAt: now,
          updatedAt: DateTime.now().toLocal(),
          note: 'Saved offline, waiting for sync',
        ),
      );
      await _refreshPendingCount();
      if (!mounted) return;
      _showMessage(
        CitizenStrings.trf(
          'report_saved_offline_pending',
          languageCode,
          <String, String>{'count': _pendingWaterLevelCount.toString()},
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingLevel = false);
    }
  }

  Future<void> _submitFloodPhoto() async {
    final String languageCode = _languageCode;
    if (!_validateZoneId()) return;
    if (_selectedImage == null) {
      _showMessage(CitizenStrings.tr('report_photo_required', languageCode));
      return;
    }

    setState(() => _sendingPhoto = true);
    final String zoneId = _normalizedZoneId();
    final DateTime now = DateTime.now().toLocal();
    final String reportId = _newReportId('photo');
    try {
      final String message = await _api.submitFloodPhoto(
        zoneId: zoneId,
        image: _selectedImage!,
      );
      await _historyStore.upsertRecord(
        CitizenReportRecord(
          id: reportId,
          type: CitizenReportType.floodPhoto,
          zoneId: zoneId,
          status: CitizenReportStatus.synced,
          createdAt: now,
          updatedAt: now,
          note: 'Photo submitted successfully',
        ),
      );
      if (!mounted) return;
      _showMessage(message);
      setState(() => _selectedImage = null);
    } catch (_) {
      await _historyStore.upsertRecord(
        CitizenReportRecord(
          id: reportId,
          type: CitizenReportType.floodPhoto,
          zoneId: zoneId,
          status: CitizenReportStatus.failed,
          createdAt: now,
          updatedAt: DateTime.now().toLocal(),
          note: 'Photo submission failed',
        ),
      );
      if (!mounted) return;
      _showMessage(
        CitizenStrings.tr('report_submission_failed_photo', languageCode),
      );
    } finally {
      if (mounted) setState(() => _sendingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String languageCode = _languageCode;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  CitizenStrings.tr(
                    'report_section_location_zone',
                    languageCode,
                  ),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      key: const Key('zone-mode-area-pincode'),
                      label: Text(
                        CitizenStrings.tr(
                          'report_mode_area_pincode',
                          languageCode,
                        ),
                      ),
                      selected: _zoneMode == 'AREA_PINCODE',
                      onSelected: (_) =>
                          setState(() => _zoneMode = 'AREA_PINCODE'),
                    ),
                    ChoiceChip(
                      key: const Key('zone-mode-custom'),
                      label: Text(
                        CitizenStrings.tr('report_mode_custom', languageCode),
                      ),
                      selected: _zoneMode == 'CUSTOM',
                      onSelected: (_) => setState(() => _zoneMode = 'CUSTOM'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_zoneMode == 'AREA_PINCODE') ...<Widget>[
                  OutlinedButton.icon(
                    key: const Key('area-gps-autofill-button'),
                    onPressed: _locatingArea ? null : _useGpsAutoFillArea,
                    icon: _locatingArea
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      _locatingArea
                          ? CitizenStrings.tr(
                              'report_detecting_location',
                              languageCode,
                            )
                          : CitizenStrings.tr(
                              'report_use_gps_autodetect',
                              languageCode,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: CitizenStrings.tr(
                        'report_city_district',
                        languageCode,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('area-city-dropdown'),
                        isExpanded: true,
                        value: _selectedCity,
                        items: _cities.map((String city) {
                          return DropdownMenuItem<String>(
                            value: city,
                            child: Text(city),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          if (value == null) return;
                          setState(() {
                            _selectedCity = value;
                            _selectedAreaSuggestion = null;
                            _localityController.clear();
                          });
                        },
                      ),
                    ),
                  ),
                  if (_areaSuggestions().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            CitizenStrings.tr(
                              'report_area_suggestions',
                              languageCode,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('area-clear-selection-button'),
                          onPressed: () {
                            setState(() {
                              _selectedAreaSuggestion = null;
                              _localityController.clear();
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: Text(
                            CitizenStrings.tr(
                              'report_clear_selected_area',
                              languageCode,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InputDecorator(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: CitizenStrings.tr(
                          'report_suggested_areas',
                          languageCode,
                        ),
                        helperText: CitizenStrings.tr(
                          'report_suggested_helper',
                          languageCode,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('area-suggestion-dropdown'),
                          isExpanded: true,
                          value:
                              _selectedAreaSuggestion != null &&
                                  _areaSuggestions().contains(
                                    _selectedAreaSuggestion,
                                  )
                              ? _selectedAreaSuggestion
                              : null,
                          hint: Text(
                            CitizenStrings.tr(
                              'report_select_area_optional',
                              languageCode,
                            ),
                          ),
                          items: <DropdownMenuItem<String>>[
                            ..._areaSuggestions().map((String area) {
                              return DropdownMenuItem<String>(
                                value: area,
                                child: Text(area),
                              );
                            }),
                          ],
                          onChanged: (String? value) {
                            setState(() {
                              if (value == null) {
                                _selectedAreaSuggestion = null;
                                _localityController.clear();
                              } else {
                                _selectedAreaSuggestion = value;
                                _localityController.text = value;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('area-locality-input'),
                    controller: _localityController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: CitizenStrings.tr(
                        'report_locality_label',
                        languageCode,
                      ),
                      hintText: CitizenStrings.tr(
                        'report_locality_hint',
                        languageCode,
                      ),
                      helperText: CitizenStrings.tr(
                        'report_locality_helper',
                        languageCode,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('area-pincode-input'),
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: CitizenStrings.tr(
                        'report_pincode_label',
                        languageCode,
                      ),
                      hintText: CitizenStrings.tr(
                        'report_pincode_hint',
                        languageCode,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CitizenStrings.trf(
                      'report_generated_zone_id',
                      languageCode,
                      <String, String>{
                        'zone': _normalizedZoneId().isEmpty
                            ? '--'
                            : _normalizedZoneId(),
                      },
                    ),
                  ),
                ],
                if (_zoneMode == 'CUSTOM')
                  TextField(
                    key: const Key('custom-zone-id-input'),
                    controller: _zoneIdController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: CitizenStrings.tr(
                        'report_custom_zone_id_label',
                        languageCode,
                      ),
                      hintText: CitizenStrings.tr(
                        'report_custom_zone_id_hint',
                        languageCode,
                      ),
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
                Text(
                  CitizenStrings.tr('report_section_flood_photo', languageCode),
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
                      label: Text(
                        CitizenStrings.tr('report_camera', languageCode),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('pick-photo-gallery'),
                      onPressed: _sendingPhoto
                          ? null
                          : () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        CitizenStrings.tr('report_gallery', languageCode),
                      ),
                    ),
                  ],
                ),
                if (_selectedImage != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    CitizenStrings.trf(
                      'report_selected_file',
                      languageCode,
                      <String, String>{'name': _selectedImage!.name},
                    ),
                  ),
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
                    _sendingPhoto
                        ? CitizenStrings.tr('report_submitting', languageCode)
                        : CitizenStrings.tr(
                            'report_submit_flood_photo',
                            languageCode,
                          ),
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
                Text(
                  CitizenStrings.tr(
                    'report_section_flooding_level',
                    languageCode,
                  ),
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
                    _sendingLevel
                        ? CitizenStrings.tr('report_submitting', languageCode)
                        : CitizenStrings.tr(
                            'report_submit_water_level',
                            languageCode,
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('sync-pending-levels-button'),
                  onPressed: _syncingPending ? null : _syncPendingWaterLevels,
                  icon: _syncingPending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    _syncingPending
                        ? CitizenStrings.tr(
                            'report_syncing_pending',
                            languageCode,
                          )
                        : CitizenStrings.trf(
                            'report_sync_pending_button',
                            languageCode,
                            <String, String>{
                              'count': _pendingWaterLevelCount.toString(),
                            },
                          ),
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
