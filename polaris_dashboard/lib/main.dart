import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/global_reload.dart';
import 'core/theme_controller.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final reload = GlobalReload();
            reload.start();
            return reload;
          },
        ),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const PolarisApp(),
    ),
  );
}
