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
            tooltip: CitizenStrings.tr('language_tooltip', languageCode),
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
      final String languageCode = CitizenPreferencesScope.of(
        context,
      ).languageCode;
      setState(() {
        _summaryError = cachedZones.isEmpty
            ? CitizenStrings.tr('dash_summary_fetch_failed', languageCode)
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

  String _updatedAgo(DateTime? timestamp, String languageCode) {
    if (timestamp == null) {
      return CitizenStrings.tr('time_unknown', languageCode);
    }
    return CitizenStrings.relativeTimeFromNow(
      timestamp.toLocal(),
      languageCode,
    );
  }

  Future<void> _callHelpline(String number) async {
    final String languageCode = CitizenPreferencesScope.of(
      context,
    ).languageCode;
    final Uri uri = Uri(scheme: 'tel', path: number);
    final bool launched = await launchUrl(uri);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CitizenStrings.trf(
              'dash_call_failed',
              languageCode,
              <String, String>{'number': number},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _fetchLiveLocation() async {
    final String languageCode = CitizenPreferencesScope.of(
      context,
    ).languageCode;
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = CitizenStrings.tr(
            'dash_location_service_disabled',
            languageCode,
          );
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = CitizenStrings.tr(
            'dash_location_permission_denied',
            languageCode,
          );
        });
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
      setState(() {
        _locationError = CitizenStrings.tr(
          'dash_location_fetch_failed',
          languageCode,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _copyLocationForHelp() async {
    final String languageCode = CitizenPreferencesScope.of(
      context,
    ).languageCode;
    final Position? p = _livePosition;
    if (p == null) return;

    final String message =
        'Emergency help needed. Current location: '
        'https://maps.google.com/?q=${p.latitude},${p.longitude}';
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(CitizenStrings.tr('dash_location_copied', languageCode)),
      ),
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
    final String languageCode = CitizenPreferencesScope.of(
      context,
    ).languageCode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  CitizenStrings.tr('dash_stay_alert_title', languageCode),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  CitizenStrings.tr('dash_stay_alert_subtitle', languageCode),
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
                      label: Text(
                        CitizenStrings.tr('dash_btn_report', languageCode),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('dashboard-go-alerts'),
                      onPressed: widget.onGoAlerts,
                      icon: const Icon(Icons.notifications_active_rounded),
                      label: Text(
                        CitizenStrings.tr('dash_btn_alerts', languageCode),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('dashboard-go-safezones'),
                      onPressed: widget.onGoSafeZones,
                      icon: const Icon(Icons.map),
                      label: Text(
                        CitizenStrings.tr('dash_btn_safe_zones', languageCode),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('dashboard-go-request-help'),
                      onPressed: widget.onGoRequestHelp,
                      icon: const Icon(Icons.sos),
                      label: Text(
                        CitizenStrings.tr(
                          'dash_btn_request_help',
                          languageCode,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('dashboard-go-myreports'),
                      onPressed: widget.onGoMyReports,
                      icon: const Icon(Icons.receipt_long),
                      label: Text(
                        CitizenStrings.tr('dash_btn_my_reports', languageCode),
                      ),
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
                Text(
                  CitizenStrings.tr('dash_live_snapshot', languageCode),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (_loadingSummary)
                  Row(
                    children: <Widget>[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CitizenStrings.tr('dash_loading_live', languageCode),
                      ),
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
                        child: Text(CitizenStrings.tr('retry', languageCode)),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        CitizenStrings.trf(
                          'dash_active_safe_zones',
                          languageCode,
                          <String, String>{
                            'count': (_activeSafeZoneCount ?? 0).toString(),
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CitizenStrings.trf(
                          'dash_safe_zones_updated',
                          languageCode,
                          <String, String>{
                            'ago': _updatedAgo(
                              _safeZonesUpdatedAt,
                              languageCode,
                            ),
                          },
                        ),
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
                Text(
                  CitizenStrings.tr('dash_what_to_report', languageCode),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(CitizenStrings.tr('dash_report_point_1', languageCode)),
                Text(CitizenStrings.tr('dash_report_point_2', languageCode)),
                Text(CitizenStrings.tr('dash_report_point_3', languageCode)),
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
                  CitizenStrings.tr('dash_immediate_safety', languageCode),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(CitizenStrings.tr('dash_safety_point_1', languageCode)),
                Text(CitizenStrings.tr('dash_safety_point_2', languageCode)),
                Text(CitizenStrings.tr('dash_safety_point_3', languageCode)),
                const SizedBox(height: 6),
                Text(CitizenStrings.tr('dash_safety_point_4', languageCode)),
                Text(CitizenStrings.tr('dash_safety_point_5', languageCode)),
                Text(
                  CitizenStrings.trf(
                    'dash_safety_freshness',
                    languageCode,
                    <String, String>{
                      'ago': _updatedAgo(_safeZonesUpdatedAt, languageCode),
                    },
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
                  CitizenStrings.tr('dash_helplines', languageCode),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(CitizenStrings.tr('dash_select_area', languageCode)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('helpline-area-dropdown'),
                  initialValue: _selectedArea,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: CitizenStrings.tr(
                      'dash_area_label',
                      languageCode,
                    ),
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
                  label: CitizenStrings.tr(
                    'dash_helpline_national',
                    languageCode,
                  ),
                  number: '112',
                  onCall: () => _callHelpline('112'),
                ),
                const SizedBox(height: 8),
                _HelplineTile(
                  key: const Key('helpline-101'),
                  label: CitizenStrings.tr('dash_helpline_fire', languageCode),
                  number: '101',
                  onCall: () => _callHelpline('101'),
                ),
                const SizedBox(height: 8),
                _HelplineTile(
                  key: const Key('helpline-108'),
                  label: CitizenStrings.tr(
                    'dash_helpline_ambulance',
                    languageCode,
                  ),
                  number: '108',
                  onCall: () => _callHelpline('108'),
                ),
                const SizedBox(height: 8),
                _HelplineTile(
                  key: const Key('helpline-1077'),
                  label: CitizenStrings.trf(
                    'dash_helpline_area_support',
                    languageCode,
                    <String, String>{'area': _selectedArea},
                  ),
                  number: '1077',
                  onCall: () => _callHelpline('1077'),
                ),
                const SizedBox(height: 8),
                Text(
                  CitizenStrings.tr('dash_helpline_tip', languageCode),
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
                Text(
                  CitizenStrings.tr('dash_live_location_title', languageCode),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  CitizenStrings.tr('dash_live_location_desc', languageCode),
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
                    _locating
                        ? CitizenStrings.tr(
                            'dash_fetching_location',
                            languageCode,
                          )
                        : CitizenStrings.tr(
                            'dash_get_live_location',
                            languageCode,
                          ),
                  ),
                ),
                if (_locationError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(_locationError!),
                ],
                if (_livePosition != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    CitizenStrings.trf(
                      'dash_lat_lng',
                      languageCode,
                      <String, String>{
                        'lat': _livePosition!.latitude.toStringAsFixed(6),
                        'lng': _livePosition!.longitude.toStringAsFixed(6),
                      },
                    ),
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
                        label: Text(
                          CitizenStrings.tr('dash_copy_help', languageCode),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('dashboard-open-maps'),
                        onPressed: _openLocationInMap,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          CitizenStrings.tr('dash_open_maps', languageCode),
                        ),
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
    final String languageCode = CitizenPreferencesScope.of(
      context,
    ).languageCode;
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
          label: Text(CitizenStrings.tr('call', languageCode)),
        ),
      ),
    );
  }
}
