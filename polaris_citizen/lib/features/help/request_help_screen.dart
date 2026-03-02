import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/settings/citizen_preferences_scope.dart';
import '../../core/settings/citizen_strings.dart';
import '../../widgets/slide_option_selector.dart';
import 'help_request.dart';
import 'help_request_api.dart';
import 'help_request_queue.dart';
import 'help_request_sync_service.dart';
import 'help_request_tracking_store.dart';

typedef HelpLocationProvider = Future<Position> Function();

class RequestHelpScreen extends StatefulWidget {
  final HelpRequestApi? api;
  final HelpRequestQueue? queue;
  final HelpRequestTrackingStore? trackingStore;
  final HelpLocationProvider? locationProvider;

  const RequestHelpScreen({
    super.key,
    this.api,
    this.queue,
    this.trackingStore,
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
  late final HelpRequestSyncService _syncService;
  late final HelpRequestTrackingStore _trackingStore;
  late final HelpLocationProvider _locationProvider;
  final TextEditingController _contactController = TextEditingController();
  String _selectedCategory = _categories.first;
  Position? _position;
  bool _locating = false;
  bool _sending = false;
  bool _refreshingTracking = false;
  bool _syncingPending = false;
  int _pendingQueueCount = 0;
  DateTime? _lastHelpSyncAt;
  List<TrackedHelpRequest> _trackedRequests = <TrackedHelpRequest>[];

  String _languageCode(BuildContext context) {
    return CitizenPreferencesScope.maybeOf(context)?.languageCode ?? 'en';
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HttpHelpRequestApi();
    _queue = widget.queue ?? SharedPrefsHelpRequestQueue();
    _syncService = HelpRequestSyncService(api: _api, queue: _queue);
    _trackingStore =
        widget.trackingStore ?? SharedPrefsHelpRequestTrackingStore();
    _locationProvider = widget.locationProvider ?? _defaultLocationProvider;
    _loadTracking();
    _loadPendingQueueCount();
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

  TrackedHelpStatus _mapBackendStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'ASSIGNED':
        return TrackedHelpStatus.assigned;
      case 'CLOSED':
      case 'RESOLVED':
        return TrackedHelpStatus.closed;
      case 'OPEN':
      default:
        return TrackedHelpStatus.received;
    }
  }

  String _trackedStatusLabel(TrackedHelpStatus status, String languageCode) {
    switch (status) {
      case TrackedHelpStatus.sent:
        return CitizenStrings.tr('help_status_sent', languageCode);
      case TrackedHelpStatus.received:
        return CitizenStrings.tr('help_status_received', languageCode);
      case TrackedHelpStatus.assigned:
        return CitizenStrings.tr('help_status_assigned', languageCode);
      case TrackedHelpStatus.closed:
        return CitizenStrings.tr('help_status_closed', languageCode);
      case TrackedHelpStatus.pendingOffline:
        return CitizenStrings.tr('help_status_pending', languageCode);
      case TrackedHelpStatus.failed:
        return CitizenStrings.tr('help_status_failed', languageCode);
    }
  }

  Color _trackedStatusColor(TrackedHelpStatus status) {
    switch (status) {
      case TrackedHelpStatus.assigned:
        return const Color(0xFF2B6CB0);
      case TrackedHelpStatus.closed:
        return const Color(0xFF2F855A);
      case TrackedHelpStatus.failed:
        return const Color(0xFFC53030);
      case TrackedHelpStatus.pendingOffline:
        return const Color(0xFFB7791F);
      case TrackedHelpStatus.sent:
      case TrackedHelpStatus.received:
        return const Color(0xFFDD6B20);
    }
  }

  Future<void> _loadTracking() async {
    final List<TrackedHelpRequest> current = await _trackingStore.list();
    if (!mounted) return;
    setState(() => _trackedRequests = current);
    await _refreshTrackingFromBackend(showMessage: false);
  }

  Future<void> _loadPendingQueueCount() async {
    final int pending = (await _queue.pending()).length;
    if (!mounted) return;
    setState(() => _pendingQueueCount = pending);
  }

  Future<void> _refreshTrackingFromBackend({bool showMessage = true}) async {
    if (_refreshingTracking) return;
    if (_trackedRequests.isEmpty) return;
    final String languageCode = _languageCode(context);
    setState(() => _refreshingTracking = true);
    try {
      final List<TrackedHelpRequest> current = await _trackingStore.list();
      for (final TrackedHelpRequest tracked in current) {
        final String? reqId = tracked.serverRequestId;
        if (reqId == null || reqId.isEmpty) continue;
        final String? status = await _api.fetchRequestStatus(reqId);
        if (status == null) continue;
        final TrackedHelpRequest next = tracked.copyWith(
          status: _mapBackendStatus(status),
          updatedAt: DateTime.now().toUtc(),
        );
        await _trackingStore.upsert(next);
      }
      final List<TrackedHelpRequest> updated = await _trackingStore.list();
      if (!mounted) return;
      setState(() => _trackedRequests = updated);
      if (showMessage) {
        _showMessage(CitizenStrings.tr('help_tracking_updated', languageCode));
      }
    } finally {
      if (mounted) setState(() => _refreshingTracking = false);
    }
  }

  Future<void> _syncPendingRequests() async {
    if (_syncingPending) return;
    final String languageCode = _languageCode(context);
    setState(() => _syncingPending = true);
    try {
      final HelpRequestSyncSummary summary = await _syncService.syncPending();
      _lastHelpSyncAt = DateTime.now().toUtc();
      await _loadPendingQueueCount();
      await _loadTracking();
      if (!mounted) return;
      if (summary.synced == 0 && summary.failed == 0 && summary.pending == 0) {
        _showMessage(CitizenStrings.tr('help_sync_none', languageCode));
      } else {
        _showMessage(
          CitizenStrings.trf(
            'help_sync_summary',
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
      if (mounted) {
        setState(() => _syncingPending = false);
      }
    }
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

  Future<void> _submitRequest() async {
    final String languageCode = _languageCode(context);
    final String contact = _contactController.text.trim();
    if (!RegExp(r'^[0-9+\-\s]{8,15}$').hasMatch(contact)) {
      _showMessage(CitizenStrings.tr('help_invalid_contact', languageCode));
      return;
    }

    setState(() => _sending = true);
    final DateTime now = DateTime.now().toUtc();
    final HelpRequest request = HelpRequest(
      id: _newRequestId(),
      category: _selectedCategory,
      contactNumber: contact,
      lat: _position?.latitude,
      lng: _position?.longitude,
      createdAt: now,
    );

    try {
      final HelpRequestSubmitResult result = await _api.submitHelpRequest(
        request,
      );
      await _trackingStore.upsert(
        TrackedHelpRequest(
          localId: request.id,
          category: request.category,
          contactNumber: request.contactNumber,
          serverRequestId: result.serverRequestId,
          status: TrackedHelpStatus.sent,
          createdAt: request.createdAt,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      await _loadTracking();
      await _loadPendingQueueCount();
      _showMessage(CitizenStrings.tr('help_sent_success', languageCode));
    } on HelpRequestHttpException {
      await _trackingStore.upsert(
        TrackedHelpRequest(
          localId: request.id,
          category: request.category,
          contactNumber: request.contactNumber,
          status: TrackedHelpStatus.failed,
          createdAt: request.createdAt,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      await _loadTracking();
      await _loadPendingQueueCount();
      _showMessage(CitizenStrings.tr('help_rejected', languageCode));
    } catch (_) {
      await _queue.enqueue(request);
      await _trackingStore.upsert(
        TrackedHelpRequest(
          localId: request.id,
          category: request.category,
          contactNumber: request.contactNumber,
          status: TrackedHelpStatus.pendingOffline,
          createdAt: request.createdAt,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      await _loadTracking();
      await _loadPendingQueueCount();
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
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  CitizenStrings.tr('help_pending_title', languageCode),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  CitizenStrings.trf(
                    'help_pending_count',
                    languageCode,
                    <String, String>{'count': _pendingQueueCount.toString()},
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CitizenStrings.trf(
                    'help_pending_last_synced',
                    languageCode,
                    <String, String>{
                      'ago': _updatedAgo(_lastHelpSyncAt, languageCode),
                    },
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('help-sync-pending-button'),
                  onPressed: _syncingPending ? null : _syncPendingRequests,
                  icon: _syncingPending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    _syncingPending
                        ? CitizenStrings.tr('help_syncing', languageCode)
                        : CitizenStrings.trf(
                            'help_sync_pending_button',
                            languageCode,
                            <String, String>{
                              'count': _pendingQueueCount.toString(),
                            },
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        CitizenStrings.tr('help_tracking_title', languageCode),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('help-tracking-refresh'),
                      onPressed: _refreshingTracking
                          ? null
                          : () => _refreshTrackingFromBackend(),
                      icon: _refreshingTracking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_trackedRequests.isEmpty)
                  Text(CitizenStrings.tr('help_tracking_empty', languageCode))
                else
                  ..._trackedRequests.take(5).map((TrackedHelpRequest tracked) {
                    final String statusLabel = _trackedStatusLabel(
                      tracked.status,
                      languageCode,
                    );
                    final String createdAgo =
                        CitizenStrings.relativeTimeFromNow(
                          tracked.createdAt.toLocal(),
                          languageCode,
                        );
                    final Color statusColor = _trackedStatusColor(
                      tracked.status,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    _categoryLabel(
                                      tracked.category,
                                      languageCode,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              CitizenStrings.trf(
                                'help_track_created',
                                languageCode,
                                <String, String>{'ago': createdAgo},
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
