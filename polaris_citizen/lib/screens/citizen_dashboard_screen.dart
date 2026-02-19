import 'package:flutter/material.dart';
import '../features/report/report_flood_screen.dart';

class CitizenDashboardScreen extends StatefulWidget {
  const CitizenDashboardScreen({super.key});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  int _selectedIndex = 0;

  static const List<String> _titles = <String>[
    'Citizen Dashboard',
    'Report Flooding',
    'Safe Zones',
  ];

  final List<Widget> _pages = const <Widget>[
    _DashboardIntroTab(),
    ReportFloodScreen(),
    _PlaceholderTab(
      title: 'Safe Zones',
      message: 'Next step: safe-zones map connected to backend endpoint.',
      icon: Icons.shield,
    ),
  ];

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

class _DashboardIntroTab extends StatelessWidget {
  const _DashboardIntroTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Citizen app has started in a separate folder.\n\n'
              'This first slice only sets up the citizen dashboard structure.\n'
              'No authority/admin screens are included.',
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _PlaceholderTab({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
