import 'package:flutter/material.dart';
import 'dart:async';
import 'app.dart';
import 'features/notifications/citizen_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final CitizenNotificationService notificationService =
      CitizenNotificationService();
  runApp(CitizenApp(notificationService: notificationService));
  unawaited(notificationService.initialize());
}
