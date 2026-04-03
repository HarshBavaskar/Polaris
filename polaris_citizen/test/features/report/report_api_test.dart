import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:polaris_citizen/features/report/report_api.dart';

class _RecordingClient extends http.BaseClient {
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(jsonEncode(<String, String>{'message': 'Citizen image received'})),
      ),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }
}

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

  test('submitFloodPhoto sends a supported JPEG content type', () async {
    final _RecordingClient client = _RecordingClient();
    final HttpCitizenReportApi api = HttpCitizenReportApi(
      baseUrl: 'http://localhost:8000',
      client: client,
    );

    final String result = await api.submitFloodPhoto(
      zoneId: 'ZN-202',
      image: XFile.fromData(
        Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0]),
        name: 'flood.jpg',
      ),
    );

    final http.MultipartRequest request =
        client.lastRequest! as http.MultipartRequest;
    expect(request.url.path, '/input/citizen/image');
    expect(request.fields['zone_id'], 'ZN-202');
    expect(request.files, hasLength(1));
    expect(request.files.single.filename, 'flood.jpg');
    expect(request.files.single.contentType.toString(), 'image/jpeg');
    expect(result, 'Citizen image received');
  });

  test('submitFloodPhoto rejects unsupported image types before upload', () async {
    final _RecordingClient client = _RecordingClient();
    final HttpCitizenReportApi api = HttpCitizenReportApi(
      baseUrl: 'http://localhost:8000',
      client: client,
    );

    await expectLater(
      api.submitFloodPhoto(
        zoneId: 'ZN-202',
        image: XFile.fromData(
          Uint8List.fromList(<int>[0x00, 0x01, 0x02, 0x03]),
          name: 'flood.heic',
        ),
      ),
      throwsA(
        isA<CitizenReportHttpException>()
            .having((CitizenReportHttpException error) => error.statusCode, 'statusCode', 415)
            .having(
              (CitizenReportHttpException error) => error.message,
              'message',
              'Only JPEG, PNG, and WEBP image uploads are allowed.',
            ),
      ),
    );
    expect(client.lastRequest, isNull);
  });
}
