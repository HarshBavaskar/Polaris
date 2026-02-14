import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'layout/app_shell.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';

class PolarisApp extends StatelessWidget {
  const PolarisApp({super.key});

  ThemeData _androidPolishedTheme(ThemeData base) {
    final c = base.colorScheme;
    final t = base.textTheme;
    return base.copyWith(
      visualDensity: VisualDensity.compact,
      splashFactory: NoSplash.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final lightTheme = isAndroidUi
        ? _androidPolishedTheme(PolarisTheme.light)
        : PolarisTheme.light;
    final darkTheme = isAndroidUi
        ? _androidPolishedTheme(PolarisTheme.dark)
        : PolarisTheme.dark;

    return MaterialApp(
      title: 'Polaris Dashboard',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeController.themeMode,
      builder: (context, child) {
        if (!isAndroidUi || child == null) return child ?? const SizedBox.shrink();
        final media = MediaQuery.of(context);
        final fixedScale = media.copyWith(
          textScaler: const TextScaler.linear(1.0),
        );
        return MediaQuery(
          data: fixedScale,
          child: DefaultTextStyle.merge(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            child: child,
          ),
        );
      },
      home: const AppShell(),
    );
  }
}
