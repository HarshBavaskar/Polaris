import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polaris_citizen/features/alerts/alerts_api.dart';

void main() {
  test('fetchAlerts requests history endpoint and parses data', () async {
    late Uri capturedUri;
    final MockClient client = MockClient((http.Request request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            '_id': 'a1',
            'severity': 'ALERT',
            'channel': 'FCM',
            'message': 'Flood risk rising in Andheri',
            'timestamp': '2026-02-19T09:30:00Z',
          },
        ]),
        200,
      );
    });

    final HttpCitizenAlertsApi api = HttpCitizenAlertsApi(
      baseUrl: 'http://localhost:8000',
      client: client,
    );
    final alerts = await api.fetchAlerts(limit: 10);

    expect(capturedUri.path, '/alerts/history');
    expect(capturedUri.queryParameters['limit'], '10');
    expect(alerts.length, 1);
    expect(alerts.first.id, 'a1');
    expect(alerts.first.severity, 'ALERT');
    expect(alerts.first.channel, 'FCM');
  });
}
