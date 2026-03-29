import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../core/api.dart';
import 'citizen_alert.dart';

abstract class CitizenAlertsApi {
  Future<List<CitizenAlert>> fetchAlerts({int limit = 30});
}

class HttpCitizenAlertsApi implements CitizenAlertsApi {
  final String baseUrl;
  final http.Client _client;

  HttpCitizenAlertsApi({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? ApiConfig.baseUrl,
      _client = client ?? http.Client();

  @override
  Future<List<CitizenAlert>> fetchAlerts({int limit = 30}) async {
    Object? lastError;
    for (final String candidateBaseUrl in _candidateBaseUrls()) {
      final Uri uri = Uri.parse(
        '$candidateBaseUrl/alerts/history',
      ).replace(queryParameters: <String, String>{'limit': '$limit'});
      try {
        final http.Response response = await _client
            .get(uri)
            .timeout(ApiConfig.requestTimeout);
        if (response.statusCode != 200) {
          lastError = Exception(
            'Alerts request failed with ${response.statusCode} at $uri',
          );
          continue;
        }

        final dynamic decoded = jsonDecode(response.body);
        if (decoded is! List<dynamic>) return <CitizenAlert>[];
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(CitizenAlert.fromJson)
            .toList();
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(
      'Failed to fetch alerts. ${ApiConfig.connectionHint} Last error: $lastError',
    );
  }

  Iterable<String> _candidateBaseUrls() {
    if (baseUrl == ApiConfig.baseUrl) {
      return ApiConfig.candidateBaseUrls;
    }
    return <String>[baseUrl];
  }
}
