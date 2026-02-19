import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';

abstract class CitizenReportApi {
  Future<String> submitWaterLevel({
    required String zoneId,
    required String level,
  });

  Future<String> submitFloodPhoto({
    required String zoneId,
    required XFile image,
  });
}

class CitizenReportHttpException implements Exception {
  final int statusCode;
  final String message;

  const CitizenReportHttpException(this.statusCode, this.message);

  @override
  String toString() => 'CitizenReportHttpException($statusCode): $message';
}

class HttpCitizenReportApi implements CitizenReportApi {
  final String baseUrl;
  final http.Client _client;

  HttpCitizenReportApi({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? ApiConfig.baseUrl,
      _client = client ?? http.Client();

  @override
  Future<String> submitWaterLevel({
    required String zoneId,
    required String level,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/input/citizen/water-level'),
      body: <String, String>{
        'zone_id': zoneId.trim(),
        'level': level.trim().toUpperCase(),
      },
    );

    if (response.statusCode != 200) {
      throw CitizenReportHttpException(
        response.statusCode,
        'Failed to submit water level',
      );
    }

    return _extractMessage(response.body, fallback: 'Water level submitted.');
  }

  @override
  Future<String> submitFloodPhoto({
    required String zoneId,
    required XFile image,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/input/citizen/image'),
    )..fields['zone_id'] = zoneId.trim();

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        await image.readAsBytes(),
        filename: image.name.isEmpty ? 'flood_image.jpg' : image.name,
      ),
    );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw CitizenReportHttpException(
        response.statusCode,
        'Failed to submit flood photo',
      );
    }

    return _extractMessage(response.body, fallback: 'Flood photo submitted.');
  }

  String _extractMessage(String body, {required String fallback}) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ?? fallback;
      }
    } catch (_) {
      return fallback;
    }
    return fallback;
  }
}
