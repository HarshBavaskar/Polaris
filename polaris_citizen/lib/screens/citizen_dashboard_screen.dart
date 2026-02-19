import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/report/report_flood_screen.dart';
import '../features/safe_zones/safe_zones_api.dart';
import '../features/safe_zones/safe_zones_screen.dart';

class CitizenDashboardScreen extends StatefulWidget {
  const CitizenDashboardScreen({super.key});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  static const List<String> _titles = <String>[
    'Citizen Dashboard',
    'Report Flooding',
    'Safe Zones',
  ];

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      _DashboardHomeTab(
        onGoReport: _openReportTab,
        onGoSafeZones: _openSafeZonesTab,
      ),
      const ReportFloodScreen(),
      const SafeZonesScreen(),
    ];
  }

  void _openReportTab() => setState(() => _selectedIndex = 1);

  void _openSafeZonesTab() => setState(() => _selectedIndex = 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.flood_outlined),
            selectedIcon: Icon(Icons.flood_rounded),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Safe Zones',
          ),
        ],
      ),
    );
  }
}

class _DashboardHomeTab extends StatefulWidget {
  final VoidCallback onGoReport;
  final VoidCallback onGoSafeZones;

  const _DashboardHomeTab({
    required this.onGoReport,
    required this.onGoSafeZones,
  });

  @override
  State<_DashboardHomeTab> createState() => _DashboardHomeTabState();
}

class _DashboardHomeTabState extends State<_DashboardHomeTab> {
  late final SafeZonesApi _safeZonesApi;
  bool _loadingSummary = true;
  String? _summaryError;
  int? _activeSafeZoneCount;

  @override
  void initState() {
    super.initState();
    _safeZonesApi = HttpSafeZonesApi();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });

    try {
      final zones = await _safeZonesApi.fetchSafeZones();
      if (!mounted) return;
      setState(() => _activeSafeZoneCount = zones.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _summaryError = 'Could not fetch live summary.');
    } finally {
      if (mounted) {
        setState(() => _loadingSummary = false);
      }
    }
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
                      key: const Key('dashboard-go-safezones'),
                      onPressed: widget.onGoSafeZones,
                      icon: const Icon(Icons.map),
                      label: const Text('Open Safe Zones Map'),
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
                  Text(
                    'Active safe zones available now: ${_activeSafeZoneCount ?? 0}',
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
              children: const <Widget>[
                Text(
                  'Immediate Safety',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text('Avoid low-lying roads and underpasses.'),
                Text('Move to marked safe zones and stay updated.'),
                Text('Call local emergency services for urgent danger.'),
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
                const Text(
                  'For Mumbai/Thane and nearby areas, call these first. For district-specific control rooms, follow local authority advisories.',
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
                  label: 'District Disaster Control Room',
                  number: '1077',
                  onCall: () => _callHelpline('1077'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tip: Save local Mumbai/Thane municipal disaster control numbers in your contacts for faster response.',
                  style: TextStyle(fontSize: 12),
                ),
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
