import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'core/settings/citizen_preferences.dart';
import 'core/settings/citizen_preferences_scope.dart';
import 'core/theme.dart';
import 'screens/citizen_dashboard_screen.dart';

class CitizenApp extends StatefulWidget {
  const CitizenApp({super.key});

  @override
  State<CitizenApp> createState() => _CitizenAppState();
}

class _CitizenAppState extends State<CitizenApp> {
  late final CitizenPreferencesController _preferences;

  ThemeData _androidPolishedTheme(ThemeData base) {
    final c = base.colorScheme;
    final t = base.textTheme;
    return base.copyWith(
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: NoSplash.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: t.copyWith(
        headlineSmall: t.headlineSmall?.copyWith(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          height: 1.15,
        ),
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
        elevation: 2.4,
        shadowColor: Colors.black.withValues(alpha: 0.14),
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
        dense: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        isDense: false,
      ),
      chipTheme: base.chipTheme.copyWith(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        labelStyle: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 2.8,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          elevation: WidgetStateProperty.resolveWith<double>((states) {
            if (states.contains(WidgetState.pressed)) return 0.8;
            return 1.4;
          }),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.14),
          ),
          backgroundColor: WidgetStatePropertyAll(c.surface),
          side: WidgetStatePropertyAll(
            BorderSide(color: c.outlineVariant, width: 0.9),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          side: WidgetStatePropertyAll<BorderSide>(
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
            themeMode: ThemeMode.system,
            builder: (BuildContext context, Widget? child) {
              if (!isAndroidUi || child == null) {
                return child ?? const SizedBox.shrink();
              }
              final MediaQueryData media = MediaQuery.of(context);
              final MediaQueryData fixedScale = media.copyWith(
                textScaler: const TextScaler.linear(1.0),
              );
              return MediaQuery(data: fixedScale, child: child);
            },
            home: const CitizenDashboardScreen(),
          ),
        );
      },
    );
  }
}
