import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/settings/citizen_preferences_scope.dart';
import '../core/settings/citizen_strings.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/help/request_help_screen.dart';
import '../features/report/report_flood_screen.dart';
import '../features/report/my_reports_screen.dart';
import '../features/safe_zones/safe_zones_api.dart';
import '../features/safe_zones/safe_zones_cache.dart';
import '../features/safe_zones/safe_zones_screen.dart';
import '../features/settings/trust_usability_screen.dart';

class CitizenDashboardScreen extends StatefulWidget {
  const CitizenDashboardScreen({super.key});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  static const List<String> _titles = <String>[
    'title_dashboard',
    'title_alerts',
    'title_report',
    'title_safe_zones',
    'title_request_help',
    'title_my_reports',
    'title_trust',
  ];

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      _DashboardHomeTab(
        onGoAlerts: _openAlertsTab,
        onGoReport: _openReportTab,
        onGoSafeZones: _openSafeZonesTab,
        onGoRequestHelp: _openRequestHelpTab,
        onGoMyReports: _openMyReportsTab,
      ),
      const AlertsScreen(),
      const ReportFloodScreen(),
      const SafeZonesScreen(),
      const RequestHelpScreen(),
      const MyReportsScreen(),
      const TrustUsabilityScreen(),
    ];
  }

  void _openAlertsTab() => setState(() => _selectedIndex = 1);

  void _openReportTab() => setState(() => _selectedIndex = 2);

  void _openSafeZonesTab() => setState(() => _selectedIndex = 3);

  void _openRequestHelpTab() => setState(() => _selectedIndex = 4);

  void _openMyReportsTab() => setState(() => _selectedIndex = 5);

  void _openTrustTab() => setState(() => _selectedIndex = 6);

  void _openFromDrawer(int index) {
    setState(() => _selectedIndex = index);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final String languageCode = CitizenPreferencesScope.of(
      context,
    ).languageCode;
    final String title = CitizenStrings.tr(
      _titles[_selectedIndex],
      languageCode,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            key: const Key('appbar-go-language'),
            tooltip: 'Language',
            onPressed: _openTrustTab,
            icon: const Icon(Icons.language_outlined),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              ListTile(
                title: Text(
                  CitizenStrings.tr('menu', languageCode),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(CitizenStrings.tr('navigation', languageCode)),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('drawer-nav-dashboard'),
                leading: const Icon(Icons.dashboard_outlined),
                title: Text(CitizenStrings.tr('dashboard', languageCode)),
                selected: _selectedIndex == 0,
                onTap: () => _openFromDrawer(0),
              ),
              ListTile(
                key: const Key('drawer-nav-alerts'),
                leading: const Icon(Icons.notifications_outlined),
                title: Text(CitizenStrings.tr('alerts', languageCode)),
                selected: _selectedIndex == 1,
                onTap: () => _openFromDrawer(1),
              ),
              ListTile(
                key: const Key('drawer-nav-report'),
                leading: const Icon(Icons.flood_outlined),
                title: Text(CitizenStrings.tr('report', languageCode)),
                selected: _selectedIndex == 2,
                onTap: () => _openFromDrawer(2),
              ),
              ListTile(
                key: const Key('drawer-nav-safezones'),
                leading: const Icon(Icons.map_outlined),
                title: Text(CitizenStrings.tr('safe_zones', languageCode)),
                selected: _selectedIndex == 3,
                onTap: () => _openFromDrawer(3),
              ),
              ListTile(
                key: const Key('drawer-nav-request-help'),
                leading: const Icon(Icons.sos_outlined),
                title: Text(CitizenStrings.tr('request_help', languageCode)),
                selected: _selectedIndex == 4,
                onTap: () => _openFromDrawer(4),
              ),
              ListTile(
                key: const Key('drawer-nav-myreports'),
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(CitizenStrings.tr('my_reports', languageCode)),
                selected: _selectedIndex == 5,
                onTap: () => _openFromDrawer(5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHomeTab extends StatefulWidget {
  final VoidCallback onGoAlerts;
  final VoidCallback onGoReport;
  final VoidCallback onGoSafeZones;
  final VoidCallback onGoRequestHelp;
  final VoidCallback onGoMyReports;

  const _DashboardHomeTab({
    required this.onGoAlerts,
    required this.onGoReport,
    required this.onGoSafeZones,
    required this.onGoRequestHelp,
    required this.onGoMyReports,
  });

  @override
  State<_DashboardHomeTab> createState() => _DashboardHomeTabState();
}

class _DashboardHomeTabState extends State<_DashboardHomeTab> {
  static const List<String> _priorityAreas = <String>[
    'Mumbai',
    'Thane',
    'Navi Mumbai',
    'Palghar',
  ];

  late final SafeZonesApi _safeZonesApi;
  late final SafeZonesCache _safeZonesCache;
  bool _loadingSummary = true;
  String? _summaryError;
  int? _activeSafeZoneCount;
  DateTime? _safeZonesUpdatedAt;
  String _selectedArea = _priorityAreas.first;
  bool _locating = false;
  Position? _livePosition;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _safeZonesApi = HttpSafeZonesApi();
    _safeZonesCache = SharedPrefsSafeZonesCache();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });

    try {
      final zones = await _safeZonesApi.fetchSafeZones();
      await _safeZonesCache.saveZones(zones);
      final DateTime? updatedAt = await _safeZonesCache.lastUpdatedAt();
      if (!mounted) return;
      setState(() {
        _activeSafeZoneCount = zones.length;
        _safeZonesUpdatedAt = updatedAt;
      });
    } catch (_) {
      final cachedZones = await _safeZonesCache.loadZones();
      final DateTime? updatedAt = await _safeZonesCache.lastUpdatedAt();
      if (!mounted) return;
      setState(() {
        _summaryError = cachedZones.isEmpty
            ? 'Could not fetch live summary.'
            : null;
        _activeSafeZoneCount = cachedZones.length;
        _safeZonesUpdatedAt = updatedAt;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSummary = false);
      }
    }
  }

  String _updatedAgo(DateTime? timestamp) {
    if (timestamp == null) return 'unknown';
    final Duration diff = DateTime.now().difference(timestamp.toLocal());
    if (diff.isNegative || diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  Future<void> _callHelpline(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    final bool launched = await launchUrl(uri);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place call to $number')),
      );
    }
  }

  Future<void> _fetchLiveLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'Location service is disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Location permission denied.');
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() => _livePosition = position);
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationError = 'Unable to fetch live location.');
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _copyLocationForHelp() async {
    final Position? p = _livePosition;
    if (p == null) return;

    final String message =
        'Emergency help needed. Current location: '
        'https://maps.google.com/?q=${p.latitude},${p.longitude}';
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location copied for sharing.')),
    );
  }

  Future<void> _openLocationInMap() async {
    final Position? p = _livePosition;
    if (p == null) return;
    final Uri uri = Uri.parse(
      'https://maps.google.com/?q=${p.latitude},${p.longitude}',
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Stay Alert. Report Flooding Fast.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use this app to submit flood photos, share water level, and find safe zones nearby.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      key: const Key('dashboard-go-report'),
                      onPressed: widget.onGoReport,
                      icon: const Icon(Icons.flood),
                      label: const Text('Report Flooding Now'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('dashboard-go-alerts'),
                      onPressed: widget.onGoAlerts,
                      icon: const Icon(Icons.notifications_active_rounded),
                      label: const Text('View Alerts'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('dashboard-go-safezones'),
                      onPressed: widget.onGoSafeZones,
                      icon: const Icon(Icons.map),
                      label: const Text('Open Safe Zones Map'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('dashboard-go-request-help'),
                      onPressed: widget.onGoRequestHelp,
                      icon: const Icon(Icons.sos),
                      label: const Text('Request Help'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('dashboard-go-myreports'),
                      onPressed: widget.onGoMyReports,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('My Report History'),
                    ),
                  ],
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
                  'Live Snapshot',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (_loadingSummary)
                  const Row(
                    children: <Widget>[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading live information...'),
                    ],
                  )
                else if (_summaryError != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_summaryError!),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const Key('dashboard-retry-summary'),
                        onPressed: _loadSummary,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Active safe zones available now: ${_activeSafeZoneCount ?? 0}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Safe zones data last updated: ${_updatedAgo(_safeZonesUpdatedAt)}',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'What To Report',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text('1. Capture clear photos of roads and water movement.'),
                Text(
                  '2. Select the closest zone ID and send current water level.',
                ),
                Text('3. Submit updates again if flooding worsens.'),
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
                  'Immediate Safety',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text('Avoid low-lying roads and underpasses.'),
                const Text('Move to marked safe zones and stay updated.'),
                const Text('Call local emergency services for urgent danger.'),
                const SizedBox(height: 6),
                const Text(
                  'Keep phone battery above 50% when heavy rain starts.',
                ),
                const Text(
                  'Share verified location with family before moving.',
                ),
                Text(
                  'Safe zone data freshness: updated ${_updatedAgo(_safeZonesUpdatedAt)}.',
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
                  'Emergency Helplines',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text('Select your area for district-wise guidance:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('helpline-area-dropdown'),
                  initialValue: _selectedArea,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Area',
                  ),
                  items: _priorityAreas.map((String area) {
                    return DropdownMenuItem<String>(
                      value: area,
                      child: Text(area),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() => _selectedArea = value);
                  },
                ),
                const SizedBox(height: 12),
                _HelplineTile(
                  key: const Key('helpline-112'),
                  label: 'National Emergency Response',
                  number: '112',
                  onCall: () => _callHelpline('112'),
                ),
                const SizedBox(height: 8),
                _HelplineTile(
                  key: const Key('helpline-101'),
                  label: 'Fire Brigade',
                  number: '101',
                  onCall: () => _callHelpline('101'),
                ),
                const SizedBox(height: 8),
                _HelplineTile(
                  key: const Key('helpline-108'),
                  label: 'Ambulance / Medical Emergency',
                  number: '108',
                  onCall: () => _callHelpline('108'),
                ),
                const SizedBox(height: 8),
                _HelplineTile(
                  key: const Key('helpline-1077'),
                  label: '$_selectedArea Emergency Support',
                  number: '1077',
                  onCall: () => _callHelpline('1077'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: Share your exact area while calling for faster response.',
                  style: TextStyle(fontSize: 12),
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
                  'Live Location for Help',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use this only when needed to quickly share your exact location with responders or family.',
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('dashboard-fetch-location'),
                  onPressed: _locating ? null : _fetchLiveLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _locating ? 'Fetching location...' : 'Get Live Location',
                  ),
                ),
                if (_locationError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(_locationError!),
                ],
                if (_livePosition != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Lat ${_livePosition!.latitude.toStringAsFixed(6)}, '
                    'Lng ${_livePosition!.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const Key('dashboard-copy-location'),
                        onPressed: _copyLocationForHelp,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Help Message'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('dashboard-open-maps'),
                        onPressed: _openLocationInMap,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open in Maps'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HelplineTile extends StatelessWidget {
  final String label;
  final String number;
  final VoidCallback onCall;

  const _HelplineTile({
    super.key,
    required this.label,
    required this.number,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        title: Text(label),
        subtitle: Text(number),
        trailing: FilledButton.tonalIcon(
          onPressed: onCall,
          icon: const Icon(Icons.call),
          label: const Text('Call'),
        ),
      ),
    );
  }
}
