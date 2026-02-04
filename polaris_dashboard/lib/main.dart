import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/global_reload.dart';
import 'layout/app_shell.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final r = GlobalReload();
        r.start(); // 🔥 STARTS AUTO REFRESH HERE
        return r;
      },
      child: const PolarisApp(),
    ),
  );
}

class PolarisApp extends StatelessWidget {
  const PolarisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppShell(),
    );
  }
}
