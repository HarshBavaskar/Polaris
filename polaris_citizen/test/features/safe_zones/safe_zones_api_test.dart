import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_api.dart';

void main() {
  test('fetchSafeZones returns only active zones', () async {
    final MockClient client = MockClient((http.Request request) async {
      expect(request.url.path, '/map/safe-zones');
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'zone_id': 'SZ-1',
            'lat': 19.076,
            'lng': 72.8777,
            'active': true,
            'source': 'AUTO',
            'confidence_level': 'HIGH',
          },
          <String, dynamic>{
            'zone_id': 'SZ-2',
            'lat': 19.08,
            'lng': 72.88,
            'active': false,
            'source': 'MANUAL',
            'confidence_level': 'MEDIUM',
          },
        ]),
        200,
      );
    });

    final HttpSafeZonesApi api = HttpSafeZonesApi(
      baseUrl: 'http://localhost:8000',
      client: client,
    );

    final zones = await api.fetchSafeZones();

    expect(zones.length, 1);
    expect(zones.first.zoneId, 'SZ-1');
    expect(zones.first.active, true);
  });
}
