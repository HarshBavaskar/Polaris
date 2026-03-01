import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'core/settings/citizen_preferences.dart';
import 'core/settings/citizen_preferences_scope.dart';
import 'core/theme.dart';
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

  ThemeData _androidPolishedTheme(ThemeData base) {
    final ColorScheme c = base.colorScheme;
    final TextTheme t = base.textTheme;
    return base.copyWith(
      visualDensity: VisualDensity.compact,
      splashFactory: NoSplash.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: t.copyWith(
        titleLarge: t.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        titleMedium: t.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 14.5, height: 1.32),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 13.5, height: 1.32),
        labelLarge: t.labelLarge?.copyWith(
          fontSize: 12.5,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        margin: EdgeInsets.zero,
        elevation: 0.8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.outlineVariant, width: 0.6),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.surface,
        elevation: 3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        isDense: true,
      ),
      chipTheme: base.chipTheme.copyWith(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        labelStyle: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: c.outlineVariant, width: 0.8),
          ),
        ),
      ),
    );
  }

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
            theme: lightTheme,
            darkTheme: darkTheme,
            builder: (BuildContext context, Widget? child) {
              if (child == null) {
                return child ?? const SizedBox.shrink();
              }
              if (!isAndroidUi) {
                return child;
              }

              final MediaQueryData media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(textScaler: const TextScaler.linear(1.0)),
                child: child,
              );
            },
            home: CitizenDashboardScreen(
              tabNavigationStream: _tabNavigationController.stream,
            ),
          ),
        );
      },
    );
  }
}
