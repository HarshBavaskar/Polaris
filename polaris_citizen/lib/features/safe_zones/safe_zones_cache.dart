import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'safe_zone.dart';

abstract class SafeZonesCache {
  Future<List<SafeZone>> loadZones();

  Future<void> saveZones(List<SafeZone> zones);

  Future<DateTime?> lastUpdatedAt();
}

class SharedPrefsSafeZonesCache implements SafeZonesCache {
  static const String _zonesKey = 'citizen.cached_safe_zones.v1';
  static const String _updatedAtKey = 'citizen.cached_safe_zones.updated_at.v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<List<SafeZone>> loadZones() async {
    final SharedPreferences prefs = await _instance();
    final String raw = prefs.getString(_zonesKey) ?? '[]';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <SafeZone>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SafeZone.fromJson)
          .where((SafeZone zone) => zone.active)
          .toList();
    } catch (_) {
      return <SafeZone>[];
    }
  }

  @override
  Future<void> saveZones(List<SafeZone> zones) async {
    final SharedPreferences prefs = await _instance();
    final String payload = jsonEncode(
      zones
          .where((SafeZone z) => z.active)
          .map((SafeZone z) => z.toJson())
          .toList(),
    );
    await prefs.setString(_zonesKey, payload);
    await prefs.setString(_updatedAtKey, DateTime.now().toUtc().toIso8601String());
  }

  @override
  Future<DateTime?> lastUpdatedAt() async {
    final SharedPreferences prefs = await _instance();
    final String raw = prefs.getString(_updatedAtKey) ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
