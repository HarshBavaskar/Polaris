import 'dart:async';

import 'package:flutter/material.dart';
import 'core/settings/citizen_preferences.dart';
import 'core/settings/citizen_preferences_scope.dart';
import 'features/notifications/citizen_notification_service.dart';
import 'screens/citizen_dashboard_screen.dart';

class CitizenApp extends StatefulWidget {
  final CitizenNotificationService? notificationService;

  const CitizenApp({super.key, this.notificationService});

  @override
  State<CitizenApp> createState() => _CitizenAppState();
}

class _CitizenAppState extends State<CitizenApp> {
  late final CitizenPreferencesController _preferences;
  final StreamController<int> _tabNavigationController =
      StreamController<int>.broadcast();
  StreamSubscription<int>? _notificationNavigationSub;

  @override
  void initState() {
    super.initState();
    _preferences = CitizenPreferencesController();
    _preferences.load();
    _notificationNavigationSub = widget.notificationService?.tabOpenRequests
        .listen((int tabIndex) {
          if (!_tabNavigationController.isClosed) {
            _tabNavigationController.add(tabIndex);
          }
        });
  }

  @override
  void dispose() {
    _notificationNavigationSub?.cancel();
    _tabNavigationController.close();
    widget.notificationService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _preferences,
      builder: (BuildContext context, Widget? child) {
        const Color seed = Color(0xFF0F766E);
        final ColorScheme scheme = ColorScheme.fromSeed(seedColor: seed);
        final ThemeData theme = ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: const Color(0xFFF4F7F8),
          appBarTheme: AppBarTheme(
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            elevation: 0,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          chipTheme: ChipThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        );
        return CitizenPreferencesScope(
          controller: _preferences,
          child: MaterialApp(
            title: 'Polaris Citizen',
            debugShowCheckedModeBanner: false,
            locale: Locale(_preferences.languageCode),
            theme: theme,
            home: CitizenDashboardScreen(
              tabNavigationStream: _tabNavigationController.stream,
            ),
          ),
        );
      },
    );
  }
}
