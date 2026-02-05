import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'side_nav.dart';
import 'top_bar.dart';

import '../screens/overview_screen.dart';
import '../screens/map_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/trends_screen.dart';
import '../screens/authority_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  final screens = const [
    OverviewScreen(),
    LiveMapScreen(),
    AlertsScreen(),
    TrendsScreen(),
    AuthorityScreen(),
  ];

  // ================= NOTIFICATION ENGINE =================
  Timer? _poller;
  String? _lastAlertId;
  OverlayEntry? _toast;

  final String baseUrl = "http://localhost:8000";

  @override
  void initState() {
    super.initState();
    _startAlertPolling();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _removeToast();
    super.dispose();
  }

  void _startAlertPolling() {
    _poller = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final res =
            await http.get(Uri.parse("$baseUrl/alerts/latest"));

        if (res.statusCode != 200) return;

        final data = jsonDecode(res.body);
        if (data == null || data["id"] == null) return;

        final String newId = data["id"];

        if (_lastAlertId == null || newId != _lastAlertId) {
          _lastAlertId = newId;
          _showToast(
            message: data["message"],
            severity: data["severity"],
          );
        }
      } catch (_) {}
    });
  }

  // ================= TOAST UI =================

  void _showToast({required String message, required String severity}) {
  _removeToast();

  final overlay = Overlay.of(
    context,
    rootOverlay: true, // 🔑 THIS FIXES IT
  );


  final color = switch (severity) {
    "EMERGENCY" => Colors.red,
    "ALERT" => Colors.orange,
    "ADVISORY" => Colors.yellow.shade800,
    _ => Colors.blue,
  };

  _toast = OverlayEntry(
    builder: (_) => Positioned(
      right: 20,
      top: 80,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  overlay.insert(_toast!);

  Future.delayed(const Duration(seconds: 6), _removeToast);
}

  void _removeToast() {
    _toast?.remove();
    _toast = null;
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SideNav(
            selectedIndex: selectedIndex,
            onSelect: (i) => setState(() => selectedIndex = i),
          ),
          Expanded(
            child: Column(
              children: [
                const TopBar(),
                Expanded(child: screens[selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
