import 'dart:convert';
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
    final response = await _client.get(Uri.parse('$baseUrl/map/safe-zones'));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch safe zones');
    }

    final List<dynamic> raw = jsonDecode(response.body) as List<dynamic>;
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SafeZone.fromJson)
        .where((SafeZone zone) => zone.active)
        .toList();
  }
}
