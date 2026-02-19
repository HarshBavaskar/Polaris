import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'report_api.dart';

class ReportFloodScreen extends StatefulWidget {
  final CitizenReportApi? api;
  final ImagePicker? imagePicker;

  const ReportFloodScreen({super.key, this.api, this.imagePicker});

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

  String _selectedLevel = 'MEDIUM';
  XFile? _selectedImage;
  bool _sendingLevel = false;
  bool _sendingPhoto = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpCitizenReportApi();
    _picker = widget.imagePicker ?? ImagePicker();
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

  String _normalizedZoneId() => _zoneIdController.text.trim();

  bool _validateZoneId() {
    if (_normalizedZoneId().isEmpty) {
      _showMessage('Please enter your zone ID.');
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
            child: TextField(
              key: const Key('zone-id-input'),
              controller: _zoneIdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Zone ID',
                hintText: 'Example: ZN-101',
              ),
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
