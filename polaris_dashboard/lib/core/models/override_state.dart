class OverrideState {
  final bool active;
  final String riskLevel;
  final String alertSeverity;
  final String reason;
  final DateTime timestamp;
  final String author;

  OverrideState({
    required this.active,
    required this.riskLevel,
    required this.alertSeverity,
    required this.reason,
    required this.timestamp,
    required this.author,
  });

  factory OverrideState.fromJson(Map<String, dynamic> json) {
    return OverrideState(
      active: json["active"] ?? false,
      riskLevel: json["risk_level"] ?? "UNKNOWN",
      alertSeverity: json["alert_severity"] ?? "UNKNOWN",
      reason: json["reason"] ?? "",
      timestamp: DateTime.parse(json["timestamp"]).toLocal(),
      author: json["author"] ?? "Unknown",
    );
  }
}
