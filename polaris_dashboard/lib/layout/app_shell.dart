import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api.dart';
import '../core/refresh_config.dart';
import '../screens/alerts_screen.dart';
import '../screens/authority_screen.dart';
import '../screens/citizen_verification_screen.dart';
import '../screens/map_screen.dart';
import '../screens/overview_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/teams_screen.dart';
import '../screens/trends_screen.dart';
import '../widgets/polaris_startup_loader.dart';
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
    'Teams',
    'Settings',
  ];

  int selectedIndex = 0;

  final screens = const [
    OverviewScreen(),
    LiveMapScreen(),
    AlertsScreen(),
    TrendsScreen(),
    CitizenVerificationScreen(),
    AuthorityScreen(),
    TeamsScreen(),
    SettingsScreen(),
  ];

  Timer? _poller;
  Timer? _startupTimer;
  bool _isPolling = false;
  bool _showStartupLoader = true;
  String? _lastAlertId;
  OverlayEntry? _toast;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final String baseUrl = ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _startAlertPolling();
    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    _startupTimer = Timer(
      Duration(milliseconds: isAndroidUi ? 650 : 1700),
      () {
      if (mounted) setState(() => _showStartupLoader = false);
      },
    );
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _poller?.cancel();
    _removeToast();
    super.dispose();
  }

  void _startAlertPolling() {
    _poller = Timer.periodic(RefreshConfig.appAlertPoll, (_) async {
      if (_isPolling) return;
      _isPolling = true;
      try {
        final res = await http.get(Uri.parse('$baseUrl/alerts/latest'));
        if (res.statusCode != 200) return;

        final decoded = jsonDecode(res.body);
        final latest = decoded is List && decoded.isNotEmpty && decoded.first is Map
            ? Map<String, dynamic>.from(decoded.first as Map)
            : decoded is Map
                ? Map<String, dynamic>.from(decoded)
                : null;
        if (latest == null) return;

        final newId = latest['_id']?.toString() ??
            latest['id']?.toString() ??
            '${latest['timestamp'] ?? ''}:${latest['message'] ?? ''}';
        if (_lastAlertId == null) {
          _lastAlertId = newId;
          return;
        }

        if (newId != _lastAlertId) {
          _lastAlertId = newId;
          _showToast(
            message: latest['message']?.toString() ?? 'New alert received',
            severity: latest['severity']?.toString() ?? 'INFO',
          );
        }
      } catch (_) {
      } finally {
        _isPolling = false;
      }
    });
  }

  void _showToast({required String message, required String severity}) {
    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (isAndroidUi) {
      final color = switch (severity) {
        'EMERGENCY' => const Color(0xFFC53030),
        'ALERT' => const Color(0xFFDD6B20),
        'ADVISORY' => const Color(0xFFB7791F),
        _ => Theme.of(context).colorScheme.primary,
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: color,
            content: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      return;
    }

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
      builder: (context) {
        final width = MediaQuery.sizeOf(context).width;
        final compact = width < 640;
        return Positioned(
          right: compact ? 12 : 20,
          left: compact ? 12 : null,
          top: compact ? 66 : 80,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: compact ? null : 360,
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
        );
      },
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
    if (_showStartupLoader) {
      return const Scaffold(
        body: Center(child: PolarisStartupLoader()),
      );
    }

    final isCompact = MediaQuery.sizeOf(context).width < 980;
    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final showBottomNav = isCompact && !isAndroidUi;
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
                      child: Padding(
                        key: ValueKey('content-$selectedIndex'),
                        padding: isCompact
                            ? const EdgeInsets.fromLTRB(8, 8, 8, 8)
                            : const EdgeInsets.fromLTRB(8, 8, 16, 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
                          child: ColoredBox(
                            color: Theme.of(context).colorScheme.surface,
                            child: isAndroidUi
                                ? IndexedStack(
                                    index: selectedIndex,
                                    children: screens,
                                  )
                                : AnimatedSwitcher(
                                    duration: RefreshConfig.screenSwitchAnimation,
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    transitionBuilder: (child, animation) {
                                      final slide = Tween<Offset>(
                                        begin: const Offset(0.02, 0),
                                        end: Offset.zero,
                                      ).animate(CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                      ));
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: slide,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: KeyedSubtree(
                                      key: ValueKey(selectedIndex),
                                      child: screens[selectedIndex],
                                    ),
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
      bottomNavigationBar: showBottomNav
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
                NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'Teams'),
                NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
              ],
            )
          : null,
    );
  }
}
