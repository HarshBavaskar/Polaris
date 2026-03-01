import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum TrackedHelpStatus {
  sent,
  received,
  assigned,
  closed,
  pendingOffline,
  failed,
}

class TrackedHelpRequest {
  final String localId;
  final String category;
  final String contactNumber;
  final String? serverRequestId;
  final TrackedHelpStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrackedHelpRequest({
    required this.localId,
    required this.category,
    required this.contactNumber,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.serverRequestId,
  });

  TrackedHelpRequest copyWith({
    String? serverRequestId,
    TrackedHelpStatus? status,
    DateTime? updatedAt,
  }) {
    return TrackedHelpRequest(
      localId: localId,
      category: category,
      contactNumber: contactNumber,
      serverRequestId: serverRequestId ?? this.serverRequestId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'local_id': localId,
    'category': category,
    'contact_number': contactNumber,
    'server_request_id': serverRequestId,
    'status': status.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static TrackedHelpRequest? fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final String localId = value['local_id']?.toString() ?? '';
    final String category = value['category']?.toString() ?? '';
    final String contact = value['contact_number']?.toString() ?? '';
    final String statusName = value['status']?.toString() ?? '';
    final DateTime? createdAt = DateTime.tryParse(
      value['created_at']?.toString() ?? '',
    );
    final DateTime? updatedAt = DateTime.tryParse(
      value['updated_at']?.toString() ?? '',
    );
    if (localId.isEmpty ||
        category.isEmpty ||
        contact.isEmpty ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }
    final TrackedHelpStatus status = TrackedHelpStatus.values.firstWhere(
      (TrackedHelpStatus s) => s.name == statusName,
      orElse: () => TrackedHelpStatus.sent,
    );
    return TrackedHelpRequest(
      localId: localId,
      category: category,
      contactNumber: contact,
      serverRequestId: value['server_request_id']?.toString(),
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

abstract class HelpRequestTrackingStore {
  Future<List<TrackedHelpRequest>> list();

  Future<void> upsert(TrackedHelpRequest tracked);
}

class SharedPrefsHelpRequestTrackingStore implements HelpRequestTrackingStore {
  static const String _key = 'citizen.help_request_tracking.v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<List<TrackedHelpRequest>> list() async {
    final SharedPreferences prefs = await _instance();
    final String raw = prefs.getString(_key) ?? '[]';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <TrackedHelpRequest>[];
      final List<TrackedHelpRequest> entries = decoded
          .map(TrackedHelpRequest.fromJson)
          .whereType<TrackedHelpRequest>()
          .toList();
      entries.sort(
        (TrackedHelpRequest a, TrackedHelpRequest b) =>
            b.createdAt.compareTo(a.createdAt),
      );
      return entries;
    } catch (_) {
      return <TrackedHelpRequest>[];
    }
  }

  @override
  Future<void> upsert(TrackedHelpRequest tracked) async {
    final List<TrackedHelpRequest> current = await list();
    final int i = current.indexWhere(
      (TrackedHelpRequest item) => item.localId == tracked.localId,
    );
    if (i == -1) {
      current.insert(0, tracked);
    } else {
      current[i] = tracked;
    }
    final List<TrackedHelpRequest> compact = current.take(30).toList();
    final SharedPreferences prefs = await _instance();
    await prefs.setString(
      _key,
      jsonEncode(compact.map((TrackedHelpRequest e) => e.toJson()).toList()),
    );
  }
}
