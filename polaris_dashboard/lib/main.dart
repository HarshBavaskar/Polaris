import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api.dart';
import 'core/global_reload.dart';
import 'core/theme_controller.dart';
import 'core/web_push_setup_stub.dart'
    if (dart.library.html) 'core/web_push_setup_web.dart';
import 'firebase_options.dart';

const String _alertsTopic = 'polaris-alerts';
const String _webVapidKey = DefaultFirebaseOptions.webVapidKey;
const String _androidNotificationChannelId = 'polaris_alerts';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();
bool _localNotificationsReady = false;

bool _looksLikeVapidPublicKey(String key) {
  // FCM web VAPID public key is a long base64url string (typically ~87 chars).
  final value = key.trim();
  if (value.length < 80) return false;
  return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialized in background isolate for Android/iOS.
  await Firebase.initializeApp();
}

Future<void> _initLocalNotifications() async {
  if (kIsWeb || _localNotificationsReady) {
    return;
  }

  const androidSettings = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );
  const settings = InitializationSettings(android: androidSettings);
  await _localNotifications.initialize(settings: settings);

  const channel = AndroidNotificationChannel(
    _androidNotificationChannelId,
    'Polaris Alerts',
    description: 'Foreground notifications for Polaris alerts',
    importance: Importance.max,
  );

  final androidPlugin =
      _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(channel);
  await androidPlugin?.requestNotificationsPermission();
  _localNotificationsReady = true;
}

Future<void> _showForegroundLocalNotification(RemoteMessage message) async {
  if (!_localNotificationsReady) {
    return;
  }

  final notification = message.notification;
  final title = notification?.title ?? 'Polaris Alert';
  final body =
      notification?.body ?? message.data['message'] ?? 'New alert received';

  const androidDetails = AndroidNotificationDetails(
    _androidNotificationChannelId,
    'Polaris Alerts',
    channelDescription: 'Foreground notifications for Polaris alerts',
    importance: Importance.max,
    priority: Priority.high,
  );

  const details = NotificationDetails(android: androidDetails);
  await _localNotifications.show(
    id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title: title,
    body: body.toString(),
    notificationDetails: details,
  );
}

Future<void> _configureFirebaseMessaging() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  String? token;
  if (kIsWeb) {
    if (_webVapidKey.isEmpty) {
      debugPrint(
        'FCM web token not requested: missing webVapidKey in firebase_options.dart',
      );
    } else if (!_looksLikeVapidPublicKey(_webVapidKey)) {
      debugPrint(
        'FCM web token not requested: webVapidKey appears invalid. '
        'Use the Web Push public key from Firebase Console.',
      );
    } else {
      try {
        token = await messaging.getToken(vapidKey: _webVapidKey);
      } catch (e) {
        debugPrint('Failed to get web FCM token: $e');
      }
    }
  } else {
    await messaging.subscribeToTopic(_alertsTopic);
    token = await messaging.getToken();
  }

  if (token != null && token.isNotEmpty) {
    debugPrint('FCM token: $token');
    await _registerTokenWithBackend(token);
  }

  messaging.onTokenRefresh.listen((String refreshedToken) async {
    debugPrint('FCM token refreshed');
    await _registerTokenWithBackend(refreshedToken);
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground FCM message: ${message.messageId}');

    if (kIsWeb) {
      // Web notifications are handled by the browser/service worker.
      // Avoid in-app Notification API popups to prevent duplicates.
      return;
    } else {
      _showForegroundLocalNotification(message);
    }
  });
}

Future<void> _registerTokenWithBackend(String token) async {
  final platform = kIsWeb
      ? 'web'
      : defaultTargetPlatform.name.toLowerCase();
  try {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/alert/register-token'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'platform': platform,
        'source': 'flutter_app',
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'FCM token registration failed: HTTP ${response.statusCode} ${response.body}',
      );
    }
  } catch (e) {
    debugPrint('Failed to register FCM token with backend: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool isMobilePushPlatform =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final bool isWebPushPlatform = kIsWeb;

  if (isWebPushPlatform) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    await ensureWebPushServiceWorkerReady();
    await _configureFirebaseMessaging();
  } else if (isMobilePushPlatform) {
    await Firebase.initializeApp();
    await _initLocalNotifications();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _configureFirebaseMessaging();
  }

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
