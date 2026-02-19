import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'citizen_alert.dart';

abstract class CitizenAlertsCache {
  Future<List<CitizenAlert>> loadAlerts();

  Future<void> saveAlerts(List<CitizenAlert> alerts);
}

class SharedPrefsCitizenAlertsCache implements CitizenAlertsCache {
  static const String _alertsKey = 'citizen.cached_alerts.v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<List<CitizenAlert>> loadAlerts() async {
    final SharedPreferences prefs = await _instance();
    final String raw = prefs.getString(_alertsKey) ?? '[]';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <CitizenAlert>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CitizenAlert.fromJson)
          .toList();
    } catch (_) {
      return <CitizenAlert>[];
    }
  }

  @override
  Future<void> saveAlerts(List<CitizenAlert> alerts) async {
    final SharedPreferences prefs = await _instance();
    final String payload = jsonEncode(
      alerts.map((CitizenAlert alert) => alert.toJson()).toList(),
    );
    await prefs.setString(_alertsKey, payload);
  }
}
