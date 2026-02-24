import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
        final bool isAndroidUi =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
        final ThemeData lightTheme = isAndroidUi
            ? _androidPolishedTheme(PolarisTheme.light)
            : PolarisTheme.light;
        final ThemeData darkTheme = isAndroidUi
            ? _androidPolishedTheme(PolarisTheme.dark)
            : PolarisTheme.dark;
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
