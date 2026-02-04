import 'package:flutter/material.dart';

Color severityColor(String severity) {
  switch (severity) {
    case "EMERGENCY":
      return const Color.fromARGB(255, 255, 0, 0);
    case "ALERT":
      return const Color.fromARGB(255, 220, 48, 0);
    case "ADVISORY":
      return const Color.fromARGB(255, 255, 102, 0);
    case "WARNING":
      return const Color.fromARGB(255, 250, 188, 17);
    case "WATCH":
      return const Color.fromARGB(255, 124, 203, 28);
    case "INFO":
      return const Color.fromARGB(255, 0, 203, 105);
    default:
      return Colors.grey;
  }
}
