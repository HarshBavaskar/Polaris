class Decision {
  final String riskLevel;
  final String alertSeverity;
  final String eta;
  final String etaConfidence;
  final double confidence;
  final String justification;
  final String decisionMode;

  Decision({
    required this.riskLevel,
    required this.alertSeverity,
    required this.eta,
    required this.etaConfidence,
    required this.confidence,
    required this.justification,
    required this.decisionMode,
  });

  factory Decision.fromJson(Map<String, dynamic> json) {
    return Decision(
      riskLevel: json["final_risk_level"] ?? "UNKNOWN",
      alertSeverity: json["final_alert_severity"] ?? "UNKNOWN",
      eta: json["final_eta"] ?? "UNKNOWN",
      etaConfidence: json["final_eta_confidence"] ?? "UNKNOWN",
      confidence: (json["final_confidence"] ?? 0).toDouble(),
      justification: json["justification"] ?? "",
      decisionMode: json["decision_state"] ?? "AUTOMATED",
    );
  }
}
