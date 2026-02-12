import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'layout/app_shell.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';

class PolarisApp extends StatelessWidget {
  const PolarisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      title: 'Polaris Command Center',
      debugShowCheckedModeBanner: false,
      theme: PolarisTheme.light,
      darkTheme: PolarisTheme.dark,
      themeMode: themeController.themeMode,
      home: const AppShell(),
    );
  }
}
