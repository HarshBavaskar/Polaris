import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/settings/citizen_preferences_scope.dart';
import '../core/settings/citizen_strings.dart';
import '../features/alerts/alerts_api.dart';
import '../features/alerts/alerts_cache.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/alerts/citizen_alert.dart';
import '../features/help/request_help_screen.dart';
import '../features/report/report_flood_screen.dart';
import '../features/report/my_reports_screen.dart';
import '../features/safe_zones/safe_zones_api.dart';
import '../features/safe_zones/safe_zones_cache.dart';
import '../features/safe_zones/safe_zones_screen.dart';
import '../features/settings/trust_usability_screen.dart';
import '../widgets/citizen_top_bar.dart';
import '../widgets/polaris_startup_loader.dart';

class CitizenDashboardScreen extends StatefulWidget {
  final Stream<int>? tabNavigationStream;

  const CitizenDashboardScreen({super.key, this.tabNavigationStream});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  int _selectedIndex = 0;
  bool _showStartupLoader = true;
  late final List<Widget> _pages;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<int>? _tabNavigationSub;
  Timer? _startupTimer;

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
    _tabNavigationSub = widget.tabNavigationStream?.listen(_openFromSignal);
    final bool isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    _startupTimer = Timer(Duration(milliseconds: isAndroidUi ? 650 : 1300), () {
      if (mounted) {
        setState(() => _showStartupLoader = false);
      }
    });
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _tabNavigationSub?.cancel();
    super.dispose();
  }

  void _openAlertsTab() => setState(() => _selectedIndex = 1);

  void _openReportTab() => setState(() => _selectedIndex = 2);

  void _openSafeZonesTab() => setState(() => _selectedIndex = 3);

  void _openRequestHelpTab() => setState(() => _selectedIndex = 4);

  void _openMyReportsTab() => setState(() => _selectedIndex = 5);

  void _openTrustTab() => setState(() => _selectedIndex = 6);

  void _openFromSignal(int index) {
    if (!mounted) return;
    final int bounded = index < 0
        ? 0
        : (index >= _pages.length ? _pages.length - 1 : index);
    setState(() => _selectedIndex = bounded);
  }

  void _openFromDrawer(int index) {
    setState(() => _selectedIndex = index);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_showStartupLoader) {
      return Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: const Center(child: PolarisStartupLoader()),
        ),
      );
    }

    final String languageCode = CitizenPreferencesScope.of(
      context,
    ).languageCode;
    final String title = CitizenStrings.tr(
      _titles[_selectedIndex],
      languageCode,
    );
    final bool isAndroidUi =
        Theme.of(context).platform == TargetPlatform.android;

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            CitizenTopBar(
              title: title,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onLanguageTap: _openTrustTab,
              languageTooltip: CitizenStrings.tr(
                'language_tooltip',
                languageCode,
              ),
            ),
            Expanded(
              child: Padding(
                padding: isAndroidUi
                    ? const EdgeInsets.fromLTRB(10, 4, 10, 10)
                    : const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _pages,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Image.asset(
                  'assets/Polaris_Logo_Side.PNG',
                  height: 44,
                  fit: BoxFit.contain,
                ),
              ),
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
  late final CitizenAlertsApi _alertsApi;
  late final CitizenAlertsCache _alertsCache;
  bool _loadingSummary = true;
  String? _summaryError;
  int? _activeSafeZoneCount;
  int? _activeAlertsCount;
  CitizenAlert? _latestAlert;
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
    _alertsApi = HttpCitizenAlertsApi();
    _alertsCache = SharedPrefsCitizenAlertsCache();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });

    bool safeZonesAvailable = false;
    bool alertsAvailable = false;

    try {
      final zones = await _safeZonesApi.fetchSafeZones();
      await _safeZonesCache.saveZones(zones);
      final DateTime? updatedAt = await _safeZonesCache.lastUpdatedAt();
      _activeSafeZoneCount = zones.length;
      _safeZonesUpdatedAt = updatedAt;
      safeZonesAvailable = true;
    } catch (_) {
      final cachedZones = await _safeZonesCache.loadZones();
      final DateTime? updatedAt = await _safeZonesCache.lastUpdatedAt();
      _activeSafeZoneCount = cachedZones.length;
      _safeZonesUpdatedAt = updatedAt;
      safeZonesAvailable = cachedZones.isNotEmpty;
    }

    try {
      final List<CitizenAlert> alerts = await _alertsApi.fetchAlerts(limit: 20);
      await _alertsCache.saveAlerts(alerts);
      _activeAlertsCount = alerts.length;
      _latestAlert = _latestByTimestamp(alerts);
      alertsAvailable = true;
    } catch (_) {
      final List<CitizenAlert> cachedAlerts = await _alertsCache.loadAlerts();
      _activeAlertsCount = cachedAlerts.length;
      _latestAlert = _latestByTimestamp(cachedAlerts);
      alertsAvailable = cachedAlerts.isNotEmpty;
    }

    if (!mounted) return;
    setState(() {
      if (!safeZonesAvailable && !alertsAvailable) {
        _summaryError = 'dash_summary_fetch_failed';
      } else if (!alertsAvailable) {
        _summaryError = 'dash_alerts_fetch_failed';
      } else {
        _summaryError = null;
      }
      _loadingSummary = false;
    });
  }

  CitizenAlert? _latestByTimestamp(List<CitizenAlert> alerts) {
    if (alerts.isEmpty) return null;
    CitizenAlert latest = alerts.first;
    for (final CitizenAlert alert in alerts.skip(1)) {
      if (alert.timestamp.isAfter(latest.timestamp)) {
        latest = alert;
      }
    }
    return latest;
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'EMERGENCY':
        return const Color(0xFFB71C1C);
      case 'ALERT':
        return const Color(0xFFDD6B20);
      case 'WARNING':
        return const Color(0xFFB7791F);
      case 'WATCH':
      case 'ADVISORY':
        return const Color(0xFF2B6CB0);
      default:
        return const Color(0xFF4A5568);
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

    final String message = CitizenStrings.trf(
      'dash_help_message_template',
      languageCode,
      <String, String>{
        'url': 'https://maps.google.com/?q=${p.latitude},${p.longitude}',
      },
    );
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
                const SizedBox(height: 12),
                Text(
                  CitizenStrings.tr('dash_emergency_actions', languageCode),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: widget.onGoReport,
                      icon: const Icon(Icons.flood),
                      label: Text(
                        CitizenStrings.tr('report', languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: widget.onGoRequestHelp,
                      icon: const Icon(Icons.sos),
                      label: Text(
                        CitizenStrings.tr('request_help', languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onGoAlerts,
                      icon: const Icon(Icons.notifications_active_rounded),
                      label: Text(
                        CitizenStrings.tr('alerts', languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onGoSafeZones,
                      icon: const Icon(Icons.shield_outlined),
                      label: Text(
                        CitizenStrings.tr('safe_zones', languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _QuickGuidanceBlock(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  CitizenStrings.tr('dash_live_snapshot', languageCode),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('dashboard-live-view-alerts'),
                        onPressed: widget.onGoAlerts,
                        icon: const Icon(Icons.notifications_active_rounded),
                        label: Text(
                          CitizenStrings.tr(
                            'dash_view_alerts_feed',
                            languageCode,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const Key('dashboard-refresh-summary'),
                      onPressed: _loadingSummary ? null : _loadSummary,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loadingSummary &&
                    _activeSafeZoneCount == null &&
                    _activeAlertsCount == null)
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
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          Chip(
                            avatar: const Icon(Icons.shield_outlined, size: 16),
                            label: Text(
                              CitizenStrings.trf(
                                'dash_active_safe_zones',
                                languageCode,
                                <String, String>{
                                  'count': (_activeSafeZoneCount ?? 0)
                                      .toString(),
                                },
                              ),
                            ),
                          ),
                          Chip(
                            avatar: const Icon(
                              Icons.notifications_active_outlined,
                              size: 16,
                            ),
                            label: Text(
                              CitizenStrings.trf(
                                'dash_active_alerts',
                                languageCode,
                                <String, String>{
                                  'count': (_activeAlertsCount ?? 0).toString(),
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_latestAlert != null)
                        Container(
                          key: const Key('dashboard-latest-alert-card'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _severityColor(
                                        _latestAlert!.severity,
                                      ).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _severityColor(
                                          _latestAlert!.severity,
                                        ).withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      _latestAlert!.severity,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _severityColor(
                                          _latestAlert!.severity,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    CitizenStrings.trf(
                                      'alerts_updated',
                                      languageCode,
                                      <String, String>{
                                        'ago': _updatedAgo(
                                          _latestAlert!.timestamp,
                                          languageCode,
                                        ),
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _latestAlert!.message,
                                key: const Key(
                                  'dashboard-latest-alert-message',
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          CitizenStrings.tr(
                            'dash_no_live_alerts',
                            languageCode,
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
                      if (_summaryError != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(CitizenStrings.tr(_summaryError!, languageCode)),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          key: const Key('dashboard-retry-summary'),
                          onPressed: _loadSummary,
                          child: Text(CitizenStrings.tr('retry', languageCode)),
                        ),
                      ],
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 360;
        final Widget callButton = FilledButton.tonalIcon(
          onPressed: onCall,
          icon: const Icon(Icons.call, size: 18),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          label: Text(
            CitizenStrings.tr('call', languageCode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );

        if (compact) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(number, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: callButton),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            dense: true,
            title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(number),
            trailing: callButton,
          ),
        );
      },
    );
  }
}

class _QuickGuidanceBlock extends StatelessWidget {
  const _QuickGuidanceBlock();

  @override
  Widget build(BuildContext context) {
    final String languageCode = CitizenPreferencesScope.of(
      context,
    ).languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              CitizenStrings.tr('dash_quick_guide_title', languageCode),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _GuideStep(
              icon: Icons.notifications_active_rounded,
              title: CitizenStrings.tr('dash_quick_step_1_title', languageCode),
              subtitle: CitizenStrings.tr(
                'dash_quick_step_1_subtitle',
                languageCode,
              ),
              accent: const Color(0xFF2B6CB0),
            ),
            const SizedBox(height: 8),
            _GuideStep(
              icon: Icons.flood,
              title: CitizenStrings.tr('dash_quick_step_2_title', languageCode),
              subtitle: CitizenStrings.tr(
                'dash_quick_step_2_subtitle',
                languageCode,
              ),
              accent: const Color(0xFFDD6B20),
            ),
            const SizedBox(height: 8),
            _GuideStep(
              icon: Icons.sos,
              title: CitizenStrings.tr('dash_quick_step_3_title', languageCode),
              subtitle: CitizenStrings.tr(
                'dash_quick_step_3_subtitle',
                languageCode,
              ),
              accent: const Color(0xFFC53030),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.1),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
