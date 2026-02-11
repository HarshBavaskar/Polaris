import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/global_reload.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final reload = GlobalReload();
        reload.start();
        return reload;
      },
      child: const PolarisApp(),
    ),
  );
}
