import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum CitizenReportType { waterLevel, floodPhoto }

enum CitizenReportStatus { synced, pendingOffline, failed }

class CitizenReportRecord {
  final String id;
  final CitizenReportType type;
  final String zoneId;
  final String? level;
  final CitizenReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;

  const CitizenReportRecord({
    required this.id,
    required this.type,
    required this.zoneId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.level,
    this.note,
  });

  CitizenReportRecord copyWith({
    CitizenReportStatus? status,
    DateTime? updatedAt,
    String? note,
  }) {
    return CitizenReportRecord(
      id: id,
      type: type,
      zoneId: zoneId,
      level: level,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'zone_id': zoneId,
      'level': level,
      'status': status.name,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'note': note,
    };
  }

  static CitizenReportRecord? fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final String id = value['id']?.toString() ?? '';
    final String zoneId = value['zone_id']?.toString() ?? '';
    if (id.isEmpty || zoneId.isEmpty) return null;

    final String typeRaw = value['type']?.toString() ?? '';
    final String statusRaw = value['status']?.toString() ?? '';
    final CitizenReportType type = CitizenReportType.values.firstWhere(
      (CitizenReportType t) => t.name == typeRaw,
      orElse: () => CitizenReportType.waterLevel,
    );
    final CitizenReportStatus status = CitizenReportStatus.values.firstWhere(
      (CitizenReportStatus s) => s.name == statusRaw,
      orElse: () => CitizenReportStatus.failed,
    );

    final DateTime createdAt =
        DateTime.tryParse(value['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now().toLocal();
    final DateTime updatedAt =
        DateTime.tryParse(value['updated_at']?.toString() ?? '')?.toLocal() ??
        createdAt;

    final String? level = value['level']?.toString();
    final String? note = value['note']?.toString();

    return CitizenReportRecord(
      id: id,
      type: type,
      zoneId: zoneId,
      level: level,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      note: note,
    );
  }
}

abstract class CitizenReportHistoryStore {
  Future<void> upsertRecord(CitizenReportRecord record);

  Future<void> markStatus({
    required String id,
    required CitizenReportStatus status,
    String? note,
  });

  Future<List<CitizenReportRecord>> listReports();
}

class SharedPrefsCitizenReportHistoryStore
    implements CitizenReportHistoryStore {
  static const String _reportsKey = 'citizen.report_history.v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<List<CitizenReportRecord>> listReports() async {
    final SharedPreferences prefs = await _instance();
    final String raw = prefs.getString(_reportsKey) ?? '[]';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <CitizenReportRecord>[];
      final List<CitizenReportRecord> records = decoded
          .map(CitizenReportRecord.fromJson)
          .whereType<CitizenReportRecord>()
          .toList();
      records.sort(
        (CitizenReportRecord a, CitizenReportRecord b) =>
            b.createdAt.compareTo(a.createdAt),
      );
      return records;
    } catch (_) {
      return <CitizenReportRecord>[];
    }
  }

  @override
  Future<void> markStatus({
    required String id,
    required CitizenReportStatus status,
    String? note,
  }) async {
    final List<CitizenReportRecord> current = await listReports();
    final int index = current.indexWhere((CitizenReportRecord r) => r.id == id);
    if (index == -1) return;
    current[index] = current[index].copyWith(
      status: status,
      updatedAt: DateTime.now().toLocal(),
      note: note,
    );
    await _save(current);
  }

  @override
  Future<void> upsertRecord(CitizenReportRecord record) async {
    final List<CitizenReportRecord> current = await listReports();
    final int index = current.indexWhere(
      (CitizenReportRecord r) => r.id == record.id,
    );
    if (index == -1) {
      current.add(record);
    } else {
      current[index] = record;
    }
    await _save(current);
  }

  Future<void> _save(List<CitizenReportRecord> records) async {
    records.sort(
      (CitizenReportRecord a, CitizenReportRecord b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    final SharedPreferences prefs = await _instance();
    final String payload = jsonEncode(
      records.map((CitizenReportRecord r) => r.toJson()).toList(),
    );
    await prefs.setString(_reportsKey, payload);
  }
}
