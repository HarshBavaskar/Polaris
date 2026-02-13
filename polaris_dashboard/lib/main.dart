import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api.dart';
import 'core/global_reload.dart';
import 'core/theme_controller.dart';
import 'core/web_notification_stub.dart'
    if (dart.library.html) 'core/web_notification_web.dart';
import 'firebase_options.dart';

const String _alertsTopic = 'polaris-alerts';
const String _webVapidKey = DefaultFirebaseOptions.webVapidKey;

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
      final notification = message.notification;
      if (notification != null) {
        showWebForegroundNotification(
          title: notification.title ?? 'Polaris Alert',
          body: notification.body ?? 'New alert received',
        );
      }
    }
  });
}

Future<void> _registerTokenWithBackend(String token) async {
  final platform = kIsWeb
      ? 'web'
      : defaultTargetPlatform.name.toLowerCase();
  try {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/alert/register-token'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'platform': platform,
        'source': 'flutter_app',
      }),
    );
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
    await _configureFirebaseMessaging();
  } else if (isMobilePushPlatform) {
    await Firebase.initializeApp();
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
