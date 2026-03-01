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
import 'models/citizen_report.dart';
import 'models/teams_snapshot.dart';

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
  static Future<List<AlertEvent>> fetchAlertHistory({
    int limit = 200,
    String? severity,
  }) async {
  final params = <String, String>{
    "limit": limit.toString(),
  };
  if (severity != null && severity.trim().isNotEmpty) {
    params["severity"] = severity.trim().toUpperCase();
  }

  final response = await http.get(
    Uri.parse("${ApiConfig.baseUrl}/alerts/history").replace(queryParameters: params),
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

static Future<void> addManualSafeZone({
  required double lat,
  required double lng,
  required int radius,
  required String reason,
  required String author,
}) async {
  final r = await http.post(
    Uri.parse("${ApiConfig.baseUrl}/safe-zones/manual/add"),
    headers: {"Content-Type": "application/json"},
    body: json.encode({
      "lat": lat,
      "lng": lng,
      "radius": radius,
      "reason": reason,
      "author": author,
    }),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to add manual safe zone");
  }
}

static Future<void> disableManualSafeZone({
  required String zoneId,
}) async {
  final r = await http.post(
    Uri.parse("${ApiConfig.baseUrl}/safe-zones/manual/disable"),
    headers: {"Content-Type": "application/json"},
    body: json.encode({
      "zone_id": zoneId,
    }),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to disable manual safe zone");
  }
}

static Future<List<CitizenReport>> fetchPendingCitizenReports() async {
  final r = await http.get(
    Uri.parse("${ApiConfig.baseUrl}/input/citizen/pending"),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to fetch pending citizen reports");
  }

  final List data = json.decode(r.body);
  return data.map((e) => CitizenReport.fromJson(e)).toList();
}

static Future<void> reviewCitizenReport({
  required String reportId,
  required String action,
  String verifier = "Authority",
  String? notes,
}) async {
  final r = await http.post(
    Uri.parse("${ApiConfig.baseUrl}/input/citizen/review"),
    headers: {"Content-Type": "application/json"},
    body: json.encode({
      "report_id": reportId,
      "action": action,
      "verifier": verifier,
      "notes": notes,
    }),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to review citizen report");
  }
}

static Future<TeamsSnapshot> fetchTeamsSnapshot() async {
  final r = await http.get(
    Uri.parse("${ApiConfig.baseUrl}/dashboard/teams/snapshot"),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to fetch teams snapshot");
  }

  return TeamsSnapshot.fromJson(json.decode(r.body));
}

static Future<void> assignTeamToHelpRequest({
  required String requestId,
  required String teamId,
  String author = "Authority",
  String? notes,
}) async {
  final r = await http.post(
    Uri.parse("${ApiConfig.baseUrl}/dashboard/help-requests/$requestId/assign-team"),
    headers: {"Content-Type": "application/json"},
    body: json.encode({
      "team_id": teamId,
      "author": author,
      "notes": notes,
    }),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to assign team");
  }
}

static Future<int> notifyNearbyTeams({
  required String requestId,
  double radiusKm = 5,
  String author = "Authority",
  String? message,
}) async {
  final r = await http.post(
    Uri.parse("${ApiConfig.baseUrl}/dashboard/help-requests/$requestId/notify-nearby"),
    headers: {"Content-Type": "application/json"},
    body: json.encode({
      "radius_km": radiusKm,
      "author": author,
      "message": message,
    }),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to notify nearby teams");
  }

  final Map<String, dynamic> data = json.decode(r.body);
  return (data["notified_count"] as num?)?.toInt() ?? 0;
}

static Future<void> upsertRescueTeam({
  required String teamId,
  required String name,
  required int membersCount,
  required String status,
  required double lat,
  required double lng,
  String? contactNumber,
}) async {
  final r = await http.post(
    Uri.parse("${ApiConfig.baseUrl}/dashboard/teams/upsert"),
    headers: {"Content-Type": "application/json"},
    body: json.encode({
      "team_id": teamId,
      "name": name,
      "members_count": membersCount,
      "status": status,
      "lat": lat,
      "lng": lng,
      "contact_number": contactNumber,
    }),
  );

  if (r.statusCode != 200) {
    throw Exception("Failed to save rescue team");
  }
}
}



