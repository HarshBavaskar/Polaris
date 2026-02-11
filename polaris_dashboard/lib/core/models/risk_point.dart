class RiskPoint {
  final double lat;
  final double lng;
  final double riskScore;
  final DateTime? timestamp;

  RiskPoint({
    required this.lat,
    required this.lng,
    required this.riskScore,
    this.timestamp,
  });

  factory RiskPoint.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json["timestamp"];
    final parsedTimestamp = rawTimestamp == null
        ? null
        : DateTime.tryParse(rawTimestamp.toString());

    return RiskPoint(
      lat: json["lat"].toDouble(),
      lng: json["lng"].toDouble(),
      riskScore: json["risk_score"].toDouble(),
      timestamp: parsedTimestamp,
    );
  }
}
