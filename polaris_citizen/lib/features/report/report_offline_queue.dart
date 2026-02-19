import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PendingWaterLevelReport {
  final String zoneId;
  final String level;
  final DateTime queuedAt;

  const PendingWaterLevelReport({
    required this.zoneId,
    required this.level,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'zone_id': zoneId,
    'level': level,
    'queued_at': queuedAt.toUtc().toIso8601String(),
  };

  static PendingWaterLevelReport? fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final String zoneId = value['zone_id']?.toString().trim() ?? '';
    final String level = value['level']?.toString().trim().toUpperCase() ?? '';
    final String queuedAtRaw = value['queued_at']?.toString() ?? '';
    if (zoneId.isEmpty || level.isEmpty || queuedAtRaw.isEmpty) return null;
    final DateTime? queuedAt = DateTime.tryParse(queuedAtRaw);
    if (queuedAt == null) return null;
    return PendingWaterLevelReport(
      zoneId: zoneId,
      level: level,
      queuedAt: queuedAt,
    );
  }
}

abstract class ReportOfflineQueue {
  Future<void> enqueueWaterLevel(PendingWaterLevelReport report);

  Future<List<PendingWaterLevelReport>> pendingWaterLevels();

  Future<void> replaceWaterLevels(List<PendingWaterLevelReport> reports);
}

class SharedPrefsReportOfflineQueue implements ReportOfflineQueue {
  static const String _waterLevelsKey = 'citizen.pending_water_levels.v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<void> enqueueWaterLevel(PendingWaterLevelReport report) async {
    final List<PendingWaterLevelReport> current = await pendingWaterLevels();
    current.add(report);
    await replaceWaterLevels(current);
  }

  @override
  Future<List<PendingWaterLevelReport>> pendingWaterLevels() async {
    final SharedPreferences prefs = await _instance();
    final String raw = prefs.getString(_waterLevelsKey) ?? '[]';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <PendingWaterLevelReport>[];
      return decoded
          .map(PendingWaterLevelReport.fromJson)
          .whereType<PendingWaterLevelReport>()
          .toList();
    } catch (_) {
      return <PendingWaterLevelReport>[];
    }
  }

  @override
  Future<void> replaceWaterLevels(List<PendingWaterLevelReport> reports) async {
    final SharedPreferences prefs = await _instance();
    final String encoded = jsonEncode(
      reports.map((PendingWaterLevelReport r) => r.toJson()).toList(),
    );
    await prefs.setString(_waterLevelsKey, encoded);
  }
}
