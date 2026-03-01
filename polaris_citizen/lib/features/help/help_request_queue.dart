import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'help_request.dart';

abstract class HelpRequestQueue {
  Future<void> enqueue(HelpRequest request);

  Future<List<HelpRequest>> pending();

  Future<void> replace(List<HelpRequest> requests);
}

class SharedPrefsHelpRequestQueue implements HelpRequestQueue {
  static const String _key = 'citizen.pending_help_requests.v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<void> enqueue(HelpRequest request) async {
    final List<HelpRequest> current = await pending();
    current.add(request);
    await replace(current);
  }

  @override
  Future<List<HelpRequest>> pending() async {
    final SharedPreferences prefs = await _instance();
    final String raw = prefs.getString(_key) ?? '[]';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <HelpRequest>[];
      return decoded
          .map(HelpRequest.fromJson)
          .whereType<HelpRequest>()
          .toList();
    } catch (_) {
      return <HelpRequest>[];
    }
  }

  @override
  Future<void> replace(List<HelpRequest> requests) async {
    final SharedPreferences prefs = await _instance();
    final String payload = jsonEncode(
      requests.map((HelpRequest r) => r.toJson()).toList(),
    );
    await prefs.setString(_key, payload);
  }
}
