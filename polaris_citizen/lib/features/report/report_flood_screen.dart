import 'package:flutter/material.dart';
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
  static const List<String> _levels = <String>[
    'LOW',
    'MEDIUM',
    'HIGH',
    'SEVERE',
  ];
  late final CitizenReportApi _api;
  late final ImagePicker _picker;
  late final SafeZonesApi _safeZonesApi;

  String _selectedLevel = 'MEDIUM';
  List<SafeZone> _safeZoneOptions = <SafeZone>[];
  String? _selectedZoneId;
  bool _useCustomZoneId = false;
  bool _loadingZones = true;
  String? _zoneLoadError;
  XFile? _selectedImage;
  bool _sendingLevel = false;
  bool _sendingPhoto = false;

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
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _normalizedZoneId() {
    if (_safeZoneOptions.isNotEmpty && !_useCustomZoneId) {
      return (_selectedZoneId ?? '').trim();
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
    if (_normalizedZoneId().isEmpty) {
      _showMessage('Please select a zone or enter a custom zone ID.');
      return false;
    }
    return true;
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
                          onChanged: _useCustomZoneId
                              ? null
                              : (String? value) {
                                  setState(() => _selectedZoneId = value);
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...<Widget>[
                    const Text(
                      'No suggested zone IDs available right now. Use custom zone ID.',
                    ),
                    const SizedBox(height: 8),
                  ],
                  CheckboxListTile(
                    key: const Key('zone-custom-toggle'),
                    value: _useCustomZoneId || _safeZoneOptions.isEmpty,
                    onChanged: _safeZoneOptions.isEmpty
                        ? null
                        : (bool? value) {
                            setState(() => _useCustomZoneId = value ?? false);
                          },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Use custom zone ID'),
                  ),
                  if (_useCustomZoneId || _safeZoneOptions.isEmpty)
                    TextField(
                      key: const Key('zone-id-input'),
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
