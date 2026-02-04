class RiskPoint {
  final double lat;
  final double lng;
  final double riskScore;

  RiskPoint({
    required this.lat,
    required this.lng,
    required this.riskScore,
  });

  factory RiskPoint.fromJson(Map<String, dynamic> json) {
    return RiskPoint(
      lat: json["lat"].toDouble(),
      lng: json["lng"].toDouble(),
      riskScore: json["risk_score"].toDouble(),
    );
  }
}
