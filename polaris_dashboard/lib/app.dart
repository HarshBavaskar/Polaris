import 'package:flutter/material.dart';
import 'layout/app_shell.dart';
import 'core/theme.dart';

class PolarisApp extends StatelessWidget {
  const PolarisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Polaris Command Center',
      debugShowCheckedModeBanner: false,
      theme: PolarisTheme.light,
      darkTheme: PolarisTheme.dark,
      home: const AppShell(),
    );
  }
}
