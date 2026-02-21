import 'package:flutter/material.dart';
import 'core/settings/citizen_preferences.dart';
import 'core/settings/citizen_preferences_scope.dart';
import 'screens/citizen_dashboard_screen.dart';

class CitizenApp extends StatefulWidget {
  const CitizenApp({super.key});

  @override
  State<CitizenApp> createState() => _CitizenAppState();
}

class _CitizenAppState extends State<CitizenApp> {
  late final CitizenPreferencesController _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = CitizenPreferencesController();
    _preferences.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _preferences,
      builder: (BuildContext context, Widget? child) {
        final ThemeData theme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        );
        return CitizenPreferencesScope(
          controller: _preferences,
          child: MaterialApp(
            title: 'Polaris Citizen',
            debugShowCheckedModeBanner: false,
            locale: Locale(_preferences.languageCode),
            theme: theme,
            home: const CitizenDashboardScreen(),
          ),
        );
      },
    );
  }
}
