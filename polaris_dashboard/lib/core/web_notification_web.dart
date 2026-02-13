// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void showWebForegroundNotification({
  required String title,
  required String body,
}) {
  if (!html.Notification.supported) return;

  if (html.Notification.permission == 'granted') {
    html.Notification(title, body: body);
    return;
  }

  if (html.Notification.permission != 'denied') {
    html.Notification.requestPermission().then((permission) {
      if (permission == 'granted') {
        html.Notification(title, body: body);
      }
    });
  }
}
