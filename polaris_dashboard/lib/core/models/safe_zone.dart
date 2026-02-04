class SafeZone {
  final double lat;
  final double lng;
  final String confidence;
  final bool active;

  SafeZone({
    required this.lat,
    required this.lng,
    required this.confidence,
    required this.active,
  });

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    return SafeZone(
      lat: json["lat"].toDouble(),
      lng: json["lng"].toDouble(),
      confidence: json["confidence"] ?? "LOW",
      active: json["active"] ?? false,
    );
  }
}
