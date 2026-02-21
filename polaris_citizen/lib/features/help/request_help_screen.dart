import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'help_request.dart';
import 'help_request_api.dart';
import 'help_request_queue.dart';

typedef HelpLocationProvider = Future<Position> Function();

class RequestHelpScreen extends StatefulWidget {
  final HelpRequestApi? api;
  final HelpRequestQueue? queue;
  final HelpLocationProvider? locationProvider;

  const RequestHelpScreen({
    super.key,
    this.api,
    this.queue,
    this.locationProvider,
  });

  @override
  State<RequestHelpScreen> createState() => _RequestHelpScreenState();
}

class _RequestHelpScreenState extends State<RequestHelpScreen> {
  static const List<String> _categories = <String>[
    'Medical',
    'Evacuation',
    'Food/Water',
  ];

  late final HelpRequestApi _api;
  late final HelpRequestQueue _queue;
  late final HelpLocationProvider _locationProvider;
  final TextEditingController _contactController = TextEditingController();
  String _selectedCategory = _categories.first;
  Position? _position;
  bool _locating = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpHelpRequestApi();
    _queue = widget.queue ?? SharedPrefsHelpRequestQueue();
    _locationProvider = widget.locationProvider ?? _defaultLocationProvider;
  }

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _detectLocation() async {
    setState(() => _locating = true);
    try {
      final Position p = await _locationProvider();
      if (!mounted) return;
      setState(() => _position = p);
      _showMessage('Live location attached.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not fetch live location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String _newRequestId() => 'help-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _submitRequest() async {
    final String contact = _contactController.text.trim();
    if (!RegExp(r'^[0-9+\-\s]{8,15}$').hasMatch(contact)) {
      _showMessage('Enter a valid contact number.');
      return;
    }

    setState(() => _sending = true);
    final HelpRequest request = HelpRequest(
      id: _newRequestId(),
      category: _selectedCategory,
      contactNumber: contact,
      lat: _position?.latitude,
      lng: _position?.longitude,
      createdAt: DateTime.now().toUtc(),
    );

    try {
      await _api.submitHelpRequest(request);
      if (!mounted) return;
      _showMessage('Help request sent successfully.');
    } on HelpRequestHttpException {
      if (!mounted) return;
      _showMessage('Help request was rejected by server.');
    } catch (_) {
      await _queue.enqueue(request);
      if (!mounted) return;
      _showMessage('No network. Help request saved offline.');
    } finally {
      if (mounted) setState(() => _sending = false);
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
                const Text(
                  'Request Help',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: 8),
                const Text(
                  'One-tap flow for urgent support. Select category, add contact number, and optional location.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((String category) {
                    return ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = category),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('help-contact-input'),
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Contact Number',
                    hintText: 'Example: 9876543210',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('help-detect-location'),
                  onPressed: _locating ? null : _detectLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _locating
                        ? 'Detecting...'
                        : 'Attach Live Location (optional)',
                  ),
                ),
                if (_position != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Lat ${_position!.latitude.toStringAsFixed(5)}, '
                    'Lng ${_position!.longitude.toStringAsFixed(5)}',
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('help-submit-button'),
                  onPressed: _sending ? null : _submitRequest,
                  icon: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sos),
                  label: Text(_sending ? 'Sending...' : 'Send Help Request'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
