import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../core/api.dart';

const String _alertsTopic = 'polaris-alerts';
const String _androidChannelId = 'polaris_citizen_alerts';

@pragma('vm:entry-point')
Future<void> citizenFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore in background if Firebase is not configured yet.
  }
}

class CitizenNotificationService {
  final http.Client _client;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final StreamController<int> _tabOpenRequests =
      StreamController<int>.broadcast();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  bool _initialized = false;
  bool _localNotificationsReady = false;
  String? _lastRegisteredToken;

  CitizenNotificationService({
    http.Client? client,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _client = client ?? http.Client(),
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  Stream<int> get tabOpenRequests => _tabOpenRequests.stream;

  bool get _isMobilePushPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!_isMobilePushPlatform) {
      return;
    }

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Citizen notifications disabled: Firebase init failed: $e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(
      citizenFirebaseMessagingBackgroundHandler,
    );
    await _initLocalNotifications();
    await _configureMessaging();
  }

  Future<void> _initLocalNotifications() async {
    if (_localNotificationsReady) return;

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (_) => _openAlertsTab(),
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _androidChannelId,
      'Citizen Alerts',
      description: 'Foreground notifications for Polaris citizen alerts',
      importance: Importance.max,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.requestNotificationsPermission();
    _localNotificationsReady = true;
  }

  Future<void> _configureMessaging() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await messaging.subscribeToTopic(_alertsTopic);

    final String? token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerTokenWithBackend(token);
    }

    _tokenRefreshSub = messaging.onTokenRefresh.listen((
      String refreshedToken,
    ) async {
      await _registerTokenWithBackend(refreshedToken);
    });

    _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _showForegroundLocalNotification(message);
      }
    });

    _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((_) {
      _openAlertsTab();
    });

    final RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _openAlertsTab();
    }
  }

  Future<void> _showForegroundLocalNotification(RemoteMessage message) async {
    if (!_localNotificationsReady) return;

    final String title = message.notification?.title ?? 'Polaris Alert';
    final String body =
        message.notification?.body ??
        (message.data['message']?.toString() ?? 'New alert received.');

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        'Citizen Alerts',
        channelDescription:
            'Foreground notifications for Polaris citizen alerts',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await _localNotifications.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      details,
      payload: 'open_alerts',
    );
  }

  Future<void> _registerTokenWithBackend(String token) async {
    if (_lastRegisteredToken == token) return;
    _lastRegisteredToken = token;

    final String platform = defaultTargetPlatform.name.toLowerCase();
    try {
      final http.Response response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/alert/register-token'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'token': token,
          'platform': platform,
          'source': 'citizen_flutter_app',
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'FCM token registration failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('FCM token registration error: $e');
    }
  }

  void _openAlertsTab() {
    if (_tabOpenRequests.isClosed) return;
    _tabOpenRequests.add(1);
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    await _tabOpenRequests.close();
    _client.close();
  }
}
