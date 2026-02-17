// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<void> ensureWebPushServiceWorkerReady() async {
  if (html.window.navigator.serviceWorker == null) return;

  // Keep path absolute so it works regardless of Flutter base href.
  await html.window.navigator.serviceWorker!.register('/firebase-messaging-sw.js');

  try {
    await html.window.navigator.serviceWorker!.ready;
  } catch (_) {
    // Let FCM token flow proceed; runtime logs in main.dart will surface issues.
  }
}
