class Prediction {
  final DateTime timestamp;
  final String riskLevel;
  final double confidence;
  final double riskScore;

  Prediction({
    required this.timestamp,
    required this.riskLevel,
    required this.confidence,
    required this.riskScore,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      timestamp: DateTime.parse(json["timestamp"]),
      riskLevel: json["risk_level"],
      confidence: (json["confidence"] ?? 0).toDouble(),
      riskScore: (json["risk_score"] ?? 0).toDouble(),
    );
  }
}
