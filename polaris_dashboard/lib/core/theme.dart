import 'package:flutter/material.dart';

class PolarisTheme {
  static const _seed = Color(0xFF1A73E8);

  static final light = _theme(Brightness.light);
  static final dark = _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;
    final scheme = baseScheme.copyWith(
      primary: const Color(0xFF1A73E8),
      secondary: const Color(0xFF00ACC1),
      tertiary: const Color(0xFFFFB300),
      surface: isDark ? const Color(0xFF121A24) : const Color(0xFFFFFFFF),
      surfaceContainerHigh:
          isDark ? const Color(0xFF182434) : const Color(0xFFF2F7FF),
      outlineVariant: isDark ? const Color(0xFF344256) : const Color(0xFFD8E3F2),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0E141E) : const Color(0xFFF6FAFF),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
