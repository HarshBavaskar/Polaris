import 'package:flutter/material.dart';
import 'app.dart';
import 'features/notifications/citizen_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final CitizenNotificationService notificationService =
      CitizenNotificationService();
  await notificationService.initialize();
  runApp(CitizenApp(notificationService: notificationService));
}
