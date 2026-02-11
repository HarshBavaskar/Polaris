import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../screens/alerts_screen.dart';
import '../screens/authority_screen.dart';
import '../screens/citizen_verification_screen.dart';
import '../screens/map_screen.dart';
import '../screens/overview_screen.dart';
import '../screens/trends_screen.dart';
import 'side_nav.dart';
import 'top_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _titles = [
    'Overview',
    'Live Map',
    'Alerts',
    'Trends',
    'Citizen Verification',
    'Authority',
  ];

  int selectedIndex = 0;

  final screens = const [
    OverviewScreen(),
    LiveMapScreen(),
    AlertsScreen(),
    TrendsScreen(),
    CitizenVerificationScreen(),
    AuthorityScreen(),
  ];

  Timer? _poller;
  String? _lastAlertId;
  OverlayEntry? _toast;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final String baseUrl = 'http://localhost:8000';

  @override
  void initState() {
    super.initState();
    _startAlertPolling();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _removeToast();
    super.dispose();
  }

  void _startAlertPolling() {
    _poller = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final res = await http.get(Uri.parse('$baseUrl/alerts/latest'));
        if (res.statusCode != 200) return;

        final data = jsonDecode(res.body);
        if (data == null || data['id'] == null) return;

        final newId = data['id'].toString();
        if (_lastAlertId == null || newId != _lastAlertId) {
          _lastAlertId = newId;
          _showToast(
            message: data['message']?.toString() ?? 'New alert received',
            severity: data['severity']?.toString() ?? 'INFO',
          );
        }
      } catch (_) {}
    });
  }

  void _showToast({required String message, required String severity}) {
    _removeToast();

    final overlay = Overlay.of(context, rootOverlay: true);
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (severity) {
      'EMERGENCY' => const Color(0xFFC53030),
      'ALERT' => const Color(0xFFDD6B20),
      'ADVISORY' => const Color(0xFFB7791F),
      _ => colorScheme.primary,
    };

    _toast = OverlayEntry(
      builder: (_) => Positioned(
        right: 20,
        top: 80,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: color.withValues(alpha: 0.97),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(_toast!);
    Future.delayed(const Duration(seconds: 6), _removeToast);
  }

  void _removeToast() {
    _toast?.remove();
    _toast = null;
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 980;
    return Scaffold(
      key: _scaffoldKey,
      drawer: isCompact
          ? Drawer(
              child: SideNav(
                selectedIndex: selectedIndex,
                compact: true,
                onSelect: (i) {
                  setState(() => selectedIndex = i);
                  Navigator.of(context).pop();
                },
              ),
            )
          : null,
      body: DecoratedBox(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
        child: SafeArea(
          child: Row(
            children: [
              if (!isCompact)
                SideNav(
                  selectedIndex: selectedIndex,
                  onSelect: (i) => setState(() => selectedIndex = i),
                ),
              Expanded(
                child: Column(
                  children: [
                    TopBar(
                      title: _titles[selectedIndex],
                      isCompact: isCompact,
                      onMenuTap: isCompact ? () => _scaffoldKey.currentState?.openDrawer() : null,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Padding(
                          key: ValueKey(selectedIndex),
                          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: ColoredBox(
                              color: Theme.of(context).colorScheme.surface,
                              child: screens[selectedIndex],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) => setState(() => selectedIndex = value),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
                NavigationDestination(icon: Icon(Icons.map_rounded), label: 'Map'),
                NavigationDestination(icon: Icon(Icons.notifications_active_rounded), label: 'Alerts'),
                NavigationDestination(icon: Icon(Icons.stacked_line_chart_rounded), label: 'Trends'),
                NavigationDestination(icon: Icon(Icons.fact_check_rounded), label: 'Verify'),
                NavigationDestination(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Authority'),
              ],
            )
          : null,
    );
  }
}
