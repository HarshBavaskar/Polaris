import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
    final String filename = image.name.isEmpty ? 'flood_image.jpg' : image.name;
    final Uint8List imageBytes = await image.readAsBytes();
    final MediaType? contentType = _resolveImageContentType(
      filename: filename,
      pickerMimeType: image.mimeType,
      bytes: imageBytes,
    );
    if (contentType == null) {
      throw const CitizenReportHttpException(
        415,
        'Only JPEG, PNG, and WEBP image uploads are allowed.',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/input/citizen/image'),
    )..fields['zone_id'] = zoneId.trim();

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: filename,
        contentType: contentType,
      ),
    );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw CitizenReportHttpException(
        response.statusCode,
        _extractMessage(
          response.body,
          fallback: 'Failed to submit flood photo',
        ),
      );
    }

    return _extractMessage(response.body, fallback: 'Flood photo submitted.');
  }

  String _extractMessage(String body, {required String fallback}) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ??
            decoded['detail']?.toString() ??
            fallback;
      }
    } catch (_) {
      return fallback;
    }
    return fallback;
  }

  MediaType? _resolveImageContentType({
    required String filename,
    required Uint8List bytes,
    String? pickerMimeType,
  }) {
    return _imageMediaTypeFromMime(pickerMimeType) ??
        _imageMediaTypeFromBytes(bytes) ??
        _imageMediaTypeFromFilename(filename);
  }

  MediaType? _imageMediaTypeFromMime(String? mimeType) {
    switch ((mimeType ?? '').trim().toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return MediaType('image', 'jpeg');
      case 'image/png':
        return MediaType('image', 'png');
      case 'image/webp':
        return MediaType('image', 'webp');
      default:
        return null;
    }
  }

  MediaType? _imageMediaTypeFromFilename(String filename) {
    final String lowerName = filename.trim().toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lowerName.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lowerName.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return null;
  }

  MediaType? _imageMediaTypeFromBytes(Uint8List bytes) {
    if (_looksLikeJpeg(bytes)) {
      return MediaType('image', 'jpeg');
    }
    if (_looksLikePng(bytes)) {
      return MediaType('image', 'png');
    }
    if (_looksLikeWebp(bytes)) {
      return MediaType('image', 'webp');
    }
    return null;
  }

  bool _looksLikeJpeg(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  bool _looksLikePng(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  bool _looksLikeWebp(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }
}
