import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../core/api.dart';
import 'safe_zone.dart';

abstract class SafeZonesApi {
  Future<List<SafeZone>> fetchSafeZones();
}

class HttpSafeZonesApi implements SafeZonesApi {
  final String baseUrl;
  final http.Client _client;

  HttpSafeZonesApi({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? ApiConfig.baseUrl,
      _client = client ?? http.Client();

  @override
  Future<List<SafeZone>> fetchSafeZones() async {
    Object? lastError;
    for (final String candidateBaseUrl in _candidateBaseUrls()) {
      final Uri uri = Uri.parse('$candidateBaseUrl/map/safe-zones');
      try {
        final http.Response response = await _client
            .get(uri)
            .timeout(ApiConfig.requestTimeout);
        if (response.statusCode != 200) {
          lastError = Exception(
            'Safe zones request failed with ${response.statusCode} at $uri',
          );
          continue;
        }

        final List<dynamic> raw = jsonDecode(response.body) as List<dynamic>;
        return raw
            .whereType<Map<String, dynamic>>()
            .map(SafeZone.fromJson)
            .where((SafeZone zone) => zone.active)
            .toList();
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(
      'Failed to fetch safe zones. ${ApiConfig.connectionHint} Last error: $lastError',
    );
  }

  Iterable<String> _candidateBaseUrls() {
    if (baseUrl == ApiConfig.baseUrl) {
      return ApiConfig.candidateBaseUrls;
    }
    return <String>[baseUrl];
  }
}
