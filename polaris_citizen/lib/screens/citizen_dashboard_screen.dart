import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/settings/citizen_preferences_scope.dart';
import '../core/settings/citizen_strings.dart';
import '../features/alerts/alerts_api.dart';
import '../features/alerts/alert_severity_palette.dart';
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

class CitizenDashboardScreen extends StatefulWidget {
  final Stream<int>? tabNavigationStream;

  const CitizenDashboardScreen({super.key, this.tabNavigationStream});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<int>? _tabNavigationSub;
  final Map<int, Widget> _pageCache = <int, Widget>{};

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
    _tabNavigationSub = widget.tabNavigationStream?.listen(_openFromSignal);
  }

  @override
  void dispose() {
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
        : (index >= _titles.length ? _titles.length - 1 : index);
    setState(() => _selectedIndex = bounded);
  }

  void _openFromDrawer(int index) {
    setState(() => _selectedIndex = index);
    Navigator.of(context).pop();
  }

  Widget _buildPage(int index) {
    return _pageCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return _DashboardHomeTab(
            onGoAlerts: _openAlertsTab,
            onGoReport: _openReportTab,
            onGoSafeZones: _openSafeZonesTab,
            onGoRequestHelp: _openRequestHelpTab,
            onGoMyReports: _openMyReportsTab,
          );
        case 1:
          return const AlertsScreen();
        case 2:
          return const ReportFloodScreen();
        case 3:
          return const SafeZonesScreen();
        case 4:
          return const RequestHelpScreen();
        case 5:
          return const MyReportsScreen();
        case 6:
          return const TrustUsabilityScreen();
        default:
          return const SizedBox.shrink();
      }
    });
  }

  Widget _buildGridButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Color onColor,
    required VoidCallback onTap,
    Key? key,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 48, color: onColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: onColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _buildPage(_selectedIndex);
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
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: _pageCache.entries.map((MapEntry<int, Widget> entry) {
                        final bool isActive = entry.key == _selectedIndex;
                        return Offstage(
                          offstage: !isActive,
                          child: TickerMode(
                            enabled: isActive,
                            child: entry.value,
                          ),
                        );
                      }).toList(growable: false),
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
              const Divider(height: 1),
              ListTile(
                key: const Key('drawer-nav-myreports'),
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(CitizenStrings.tr('my_reports', languageCode)),
                selected: _selectedIndex == 5,
                onTap: () => _openFromDrawer(5),
              ),
              ListTile(
                key: const Key('drawer-nav-trust'),
                leading: const Icon(Icons.language_outlined),
                title: Text(CitizenStrings.tr('trust', languageCode)),
                selected: _selectedIndex == 6,
                onTap: () => _openFromDrawer(6),
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
  bool _showMoreHelplines = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSummary();
      }
    });
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
    } catch (error) {
      debugPrint('Safe zones fetch failed: $error');
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
    } catch (error) {
      debugPrint('Alerts fetch failed: $error');
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

  Widget _buildGridButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Color onColor,
    required VoidCallback onTap,
    Key? key,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 48, color: onColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: onColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String languageCode = CitizenPreferencesScope.of(
      context,
    ).languageCode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        // 1. Emergency 112 Flat Solid Banner
        InkWell(
          key: const Key('dashboard-call-112'),
          onTap: () => _callHelpline('112'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFB71C1C), // Deep Red
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.phone_in_talk, size: 48, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        CitizenStrings.tr('dash_call_112_now', languageCode).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CitizenStrings.tr('dash_emergency_tools_title', languageCode),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Main Action Grid
        Row(
          children: <Widget>[
            _buildGridButton(
              context: context,
              title: CitizenStrings.tr('dash_btn_need_help', languageCode),
              icon: Icons.sos_rounded,
              color: const Color(0xFFD32F2F),
              onColor: Colors.white,
              onTap: widget.onGoRequestHelp,
              key: const Key('dashboard-primary-help'),
            ),
            const SizedBox(width: 12),
            _buildGridButton(
              context: context,
              title: CitizenStrings.tr('dash_btn_see_alerts', languageCode),
              icon: Icons.notifications_active_rounded,
              color: const Color(0xFFF57C00),
              onColor: Colors.white,
              onTap: widget.onGoAlerts,
              key: const Key('dashboard-primary-alerts'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            _buildGridButton(
              context: context,
              title: CitizenStrings.tr('dash_btn_find_safe_place', languageCode),
              icon: Icons.shield_rounded,
              color: const Color(0xFF388E3C),
              onColor: Colors.white,
              onTap: widget.onGoSafeZones,
            ),
            const SizedBox(width: 12),
            _buildGridButton(
              context: context,
              title: CitizenStrings.tr('dash_btn_report_flooding', languageCode),
              icon: Icons.flood_rounded,
              color: const Color(0xFF1976D2),
              onColor: Colors.white,
              onTap: widget.onGoReport,
            ),
          ],
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              CitizenStrings.tr('dash_live_snapshot', languageCode),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            IconButton(
              key: const Key('dashboard-refresh-summary'),
              onPressed: _loadingSummary ? null : _loadSummary,
              icon: _loadingSummary 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Latest Alert Solid Block
        if (_latestAlert != null)
          Container(
            key: const Key('dashboard-latest-alert-card'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: citizenAlertSeverityColor(_latestAlert!.severity).withValues(alpha: 0.15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.warning_rounded,
                      color: citizenAlertSeverityColor(_latestAlert!.severity),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        CitizenStrings.tr('dash_latest_alert', languageCode).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: citizenAlertSeverityColor(_latestAlert!.severity),
                        ),
                      ),
                    ),
                    Text(
                      _updatedAgo(_latestAlert!.timestamp, languageCode),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: citizenAlertSeverityColor(_latestAlert!.severity),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _latestAlert!.message,
                  key: const Key('dashboard-latest-alert-message'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    CitizenStrings.tr('dash_no_live_alerts', languageCode),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Active Status row
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.shield_rounded, color: Colors.green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (_activeSafeZoneCount ?? 0).toString(),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                          ),
                          Text(
                            CitizenStrings.tr('safe_zones', languageCode),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: widget.onGoAlerts,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.notifications_active_rounded, color: Colors.orange, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              (_activeAlertsCount ?? 0).toString(),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                            ),
                            Text(
                              CitizenStrings.tr('alerts', languageCode),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Utility Row: Location & More Helplines
        Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                key: const Key('dashboard-fetch-location'),
                onTap: _locating ? null : _fetchLiveLocation,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: <Widget>[
                      _locating
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded),
                      const SizedBox(height: 8),
                      Text(
                        _locating
                            ? CitizenStrings.tr('dash_fetching_location', languageCode)
                            : CitizenStrings.tr('dash_share_my_location', languageCode),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                key: const Key('dashboard-toggle-helplines'),
                onTap: () => setState(() => _showMoreHelplines = !_showMoreHelplines),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: <Widget>[
                      Icon(_showMoreHelplines ? Icons.keyboard_arrow_up_rounded : Icons.phone_in_talk_rounded),
                      const SizedBox(height: 8),
                      Text(
                        CitizenStrings.tr(
                          _showMoreHelplines ? 'dash_hide_helplines' : 'dash_more_helplines',
                          languageCode,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_showMoreHelplines) ...<Widget>[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(CitizenStrings.tr('dash_select_area', languageCode), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('helpline-area-dropdown'),
                  initialValue: _selectedArea,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    labelText: CitizenStrings.tr('dash_area_label', languageCode),
                  ),
                  items: _priorityAreas.map((String area) {
                    return DropdownMenuItem<String>(value: area, child: Text(area));
                  }).toList(),
                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() => _selectedArea = value);
                  },
                ),
                const SizedBox(height: 12),
                _HelplineTile(
                  key: const Key('helpline-101'),
                  label: CitizenStrings.tr('dash_helpline_fire', languageCode),
                  number: '101',
                  onCall: () => _callHelpline('101'),
                ),
                const SizedBox(height: 8),
                _HelplineTile(
                  key: const Key('helpline-108'),
                  label: CitizenStrings.tr('dash_helpline_ambulance', languageCode),
                  number: '108',
                  onCall: () => _callHelpline('108'),
                ),
                const SizedBox(height: 8),
                _HelplineTile(
                  key: const Key('helpline-1077'),
                  label: CitizenStrings.trf('dash_helpline_area_support', languageCode, <String, String>{'area': _selectedArea}),
                  number: '1077',
                  onCall: () => _callHelpline('1077'),
                ),
              ],
            ),
          ),
        ],

        if (_locationError != null) ...<Widget>[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_livePosition != null) ...<Widget>[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.pin_drop, color: Theme.of(context).colorScheme.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        CitizenStrings.trf('dash_lat_lng', languageCode, <String, String>{
                          'lat': _livePosition!.latitude.toStringAsFixed(6),
                          'lng': _livePosition!.longitude.toStringAsFixed(6),
                        }),
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('dashboard-copy-location'),
                        onPressed: _copyLocationForHelp,
                        icon: const Icon(Icons.copy),
                        label: Text(CitizenStrings.tr('dash_copy_help', languageCode)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('dashboard-open-maps'),
                        onPressed: _openLocationInMap,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(CitizenStrings.tr('dash_open_maps', languageCode)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildGridButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Color onColor,
    required VoidCallback onTap,
    Key? key,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 48, color: onColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: onColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
