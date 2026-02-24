import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/settings/citizen_preferences_scope.dart';
import '../../core/settings/citizen_strings.dart';
import '../../widgets/slide_option_selector.dart';
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

  String _languageCode(BuildContext context) {
    return CitizenPreferencesScope.maybeOf(context)?.languageCode ?? 'en';
  }

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
    final String languageCode = _languageCode(context);
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        CitizenStrings.tr('help_location_service_disabled', languageCode),
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
        CitizenStrings.tr('help_location_permission_denied', languageCode),
      );
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
    final String languageCode = _languageCode(context);
    setState(() => _locating = true);
    try {
      final Position p = await _locationProvider();
      if (!mounted) return;
      setState(() => _position = p);
      _showMessage(
        CitizenStrings.tr('help_live_location_attached', languageCode),
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        CitizenStrings.tr('help_live_location_fetch_failed', languageCode),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String _newRequestId() => 'help-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _submitRequest() async {
    final String languageCode = _languageCode(context);
    final String contact = _contactController.text.trim();
    if (!RegExp(r'^[0-9+\-\s]{8,15}$').hasMatch(contact)) {
      _showMessage(CitizenStrings.tr('help_invalid_contact', languageCode));
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
      _showMessage(CitizenStrings.tr('help_sent_success', languageCode));
    } on HelpRequestHttpException {
      if (!mounted) return;
      _showMessage(CitizenStrings.tr('help_rejected', languageCode));
    } catch (_) {
      await _queue.enqueue(request);
      if (!mounted) return;
      _showMessage(CitizenStrings.tr('help_saved_offline', languageCode));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _categoryLabel(String category, String languageCode) {
    switch (category) {
      case 'Medical':
        return CitizenStrings.tr('help_category_medical', languageCode);
      case 'Evacuation':
        return CitizenStrings.tr('help_category_evacuation', languageCode);
      case 'Food/Water':
        return CitizenStrings.tr('help_category_food_water', languageCode);
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String languageCode = _languageCode(context);
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
                  CitizenStrings.tr('help_title', languageCode),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(CitizenStrings.tr('help_desc', languageCode)),
                const SizedBox(height: 12),
                SlideOptionSelector<String>(
                  options: _categories,
                  selected: _selectedCategory,
                  labelBuilder: (String category) =>
                      _categoryLabel(category, languageCode),
                  onSelected: (String category) =>
                      setState(() => _selectedCategory = category),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('help-contact-input'),
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: CitizenStrings.tr(
                      'help_contact_label',
                      languageCode,
                    ),
                    hintText: CitizenStrings.tr(
                      'help_contact_hint',
                      languageCode,
                    ),
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
                        ? CitizenStrings.tr('help_detecting', languageCode)
                        : CitizenStrings.tr(
                            'help_attach_location_optional',
                            languageCode,
                          ),
                  ),
                ),
                if (_position != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    CitizenStrings.trf(
                      'dash_lat_lng',
                      languageCode,
                      <String, String>{
                        'lat': _position!.latitude.toStringAsFixed(5),
                        'lng': _position!.longitude.toStringAsFixed(5),
                      },
                    ),
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
                  label: Text(
                    _sending
                        ? CitizenStrings.tr('help_sending', languageCode)
                        : CitizenStrings.tr('help_send', languageCode),
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
