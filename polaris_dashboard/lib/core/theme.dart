import 'package:flutter/material.dart';

class PolarisTheme {
  static final light = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    primaryColor: Colors.blueGrey,
    useMaterial3: true,
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    primaryColor: Colors.blueGrey,
    useMaterial3: true,
  );
}
