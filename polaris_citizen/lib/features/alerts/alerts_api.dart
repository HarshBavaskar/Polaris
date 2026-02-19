import 'dart:convert';
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
    final Uri uri = Uri.parse(
      '$baseUrl/alerts/history',
    ).replace(queryParameters: <String, String>{'limit': '$limit'});
    final http.Response response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch alerts');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) return <CitizenAlert>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(CitizenAlert.fromJson)
        .toList();
  }
}
