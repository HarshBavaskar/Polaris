import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'models/decision.dart';
import 'models/risk_point.dart';
import 'models/alert_event.dart';
import 'models/override_state.dart';
import 'models/safe_zone.dart';
import 'models/historical_incident.dart';
import 'models/prediction.dart';

class ApiService {

// Fetch the latest decision from the backend API
  static Future<Decision> fetchLatestDecision() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/decision/latest"),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to fetch decision");
    }

    final data = json.decode(response.body);
    return Decision.fromJson(data);
  }


// Fetch live risk points for the map
  static Future<List<RiskPoint>> fetchLiveRiskPoints() async {
  final response = await http.get(
    Uri.parse("${ApiConfig.baseUrl}/map/live-risk"),
  );

  if (response.statusCode != 200) {
    throw Exception("Failed to fetch live risk points");
  }

  final List data = json.decode(response.body);
  return data.map((e) => RiskPoint.fromJson(e)).toList();
  }


// Fetch alert history from the backend API
  static Future<List<AlertEvent>> fetchAlertHistory() async {
  final response = await http.get(
    Uri.parse("${ApiConfig.baseUrl}/alerts/history"),
  );

  if (response.statusCode != 200) {
    throw Exception("Failed to fetch alert history");
  }

  final List data = json.decode(response.body);
  return data.map((e) => AlertEvent.fromJson(e)).toList();
 }
 // Active override
  static Future<OverrideState?> fetchActiveOverride() async {
  final r = await http.get(
    Uri.parse("${ApiConfig.baseUrl}/override/active"),
  );

  if (r.statusCode == 404) {
    return null; // NO ACTIVE OVERRIDE IS NORMAL
  }

  if (r.statusCode != 200) {
    throw Exception("Failed to fetch active override");
  }

  return OverrideState.fromJson(json.decode(r.body));
  }

  // Set override
  static Future<void> setOverride({
  required String riskLevel,
  required String alertSeverity,
  required String reason,
  required String author,
  }) async {
  final r = await http.post(
    Uri.parse("${ApiConfig.baseUrl}/override/set"),
    headers: {"Content-Type": "application/json"},
    body: json.encode({
      "risk_level": riskLevel,
      "alert_severity": alertSeverity,
      "reason": reason,
      "author": author,
    }),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to set override");
    }
  }

  // History
  static Future<List<OverrideState>> fetchOverrideHistory() async {
  final r = await http.get(
    Uri.parse("${ApiConfig.baseUrl}/override/history"),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to fetch override history");
  }

  final List data = json.decode(r.body);
  return data.map((e) => OverrideState.fromJson(e)).toList();
  }
  // Safe zones
  static Future<List<SafeZone>> fetchSafeZones() async {
  final r = await http.get(
    Uri.parse("${ApiConfig.baseUrl}/map/safe-zones"),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to fetch safe zones");
  }

  final List data = json.decode(r.body);
  return data.map((e) => SafeZone.fromJson(e)).toList();
}

// Historical incidents
  static Future<List<HistoricalIncident>> fetchHistoricalIncidents() async {
  final r = await http.get(
    Uri.parse("${ApiConfig.baseUrl}/map/historical-incidents"),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to fetch historical incidents");
  }

  final List data = json.decode(r.body);
  return data.map((e) => HistoricalIncident.fromJson(e)).toList();
}
static Future<List<Prediction>> fetchPredictionHistory() async {
  final r = await http.get(
    Uri.parse("${ApiConfig.baseUrl}/predictions/history?limit=100"),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to fetch prediction history");
  }

  final List data = json.decode(r.body);
  return data.map((e) => Prediction.fromJson(e)).toList();
}
}




