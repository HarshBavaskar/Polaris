import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../core/api.dart';
import 'help_request.dart';

abstract class HelpRequestApi {
  Future<HelpRequestSubmitResult> submitHelpRequest(HelpRequest request);

  Future<String?> fetchRequestStatus(String requestId);
}

class HelpRequestHttpException implements Exception {
  final int statusCode;
  final String message;

  const HelpRequestHttpException(this.statusCode, this.message);
}

class HelpRequestSubmitResult {
  final String? serverRequestId;
  final DateTime? createdAt;

  const HelpRequestSubmitResult({this.serverRequestId, this.createdAt});
}

class HttpHelpRequestApi implements HelpRequestApi {
  final String baseUrl;
  final http.Client _client;

  HttpHelpRequestApi({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? ApiConfig.baseUrl,
      _client = client ?? http.Client();

  @override
  Future<HelpRequestSubmitResult> submitHelpRequest(HelpRequest request) async {
    final Map<String, String> body = <String, String>{
      'category': request.category,
      'contact_number': request.contactNumber,
      if (request.lat != null) 'lat': request.lat!.toString(),
      if (request.lng != null) 'lng': request.lng!.toString(),
    };
    final http.Response response = await _client.post(
      Uri.parse('$baseUrl/input/citizen/help-request'),
      body: body,
    );
    if (response.statusCode != 200) {
      throw HelpRequestHttpException(
        response.statusCode,
        'Failed to submit help request',
      );
    }
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return HelpRequestSubmitResult(
          serverRequestId: decoded['request_id']?.toString(),
          createdAt: DateTime.tryParse(decoded['created_at']?.toString() ?? ''),
        );
      }
    } catch (_) {
      // Ignore invalid payload and fallback below.
    }
    return const HelpRequestSubmitResult();
  }

  @override
  Future<String?> fetchRequestStatus(String requestId) async {
    final Uri uri = Uri.parse('$baseUrl/dashboard/help-requests').replace(
      queryParameters: <String, String>{'status': 'ALL', 'limit': '150'},
    );
    final http.Response response = await _client.get(uri);
    if (response.statusCode != 200) return null;
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! List<dynamic>) return null;
      for (final dynamic item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        if (item['request_id']?.toString() == requestId) {
          return item['status']?.toString().toUpperCase();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
