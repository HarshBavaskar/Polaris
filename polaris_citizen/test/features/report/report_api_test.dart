import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polaris_citizen/features/report/report_api.dart';

void main() {
  test('submitWaterLevel posts expected form data', () async {
    late Uri capturedUri;
    late Map<String, String> form;

    final MockClient client = MockClient((http.Request request) async {
      capturedUri = request.url;
      form = Uri.splitQueryString(request.body);
      return http.Response(
        jsonEncode(<String, String>{'message': 'Water level report received'}),
        200,
      );
    });

    final HttpCitizenReportApi api = HttpCitizenReportApi(
      baseUrl: 'http://localhost:8000',
      client: client,
    );

    final String result = await api.submitWaterLevel(
      zoneId: 'ZN-202',
      level: 'high',
    );

    expect(capturedUri.path, '/input/citizen/water-level');
    expect(form['zone_id'], 'ZN-202');
    expect(form['level'], 'HIGH');
    expect(result, 'Water level report received');
  });
}
