import 'package:flutter/material.dart';

Color citizenAlertSeverityColor(String severity) {
  switch (severity.toUpperCase()) {
    case 'EMERGENCY':
      return const Color(0xFFB71C1C);
    case 'ALERT':
      return const Color(0xFFDD6B20);
    case 'WARNING':
      return const Color(0xFFB7791F);
    case 'WATCH':
      return const Color(0xFF2B6CB0);
    case 'ADVISORY':
      return const Color(0xFF2F855A);
    case 'INFO':
      return const Color(0xFF4A5568);
    default:
      return const Color(0xFF4A5568);
  }
}
