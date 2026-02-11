class SafeZone {
  final String zoneId;
  final double lat;
  final double lng;
  final int radius;
  final String confidence;
  final bool active;
  final String source;
  final String? reason;
  final String? author;

  SafeZone({
    required this.zoneId,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.confidence,
    required this.active,
    required this.source,
    this.reason,
    this.author,
  });

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    final latValue = (json["lat"] as num?)?.toDouble() ?? 0;
    final lngValue = (json["lng"] as num?)?.toDouble() ?? 0;
    final radiusValue = (json["radius"] as num?)?.toInt() ?? 300;

    return SafeZone(
      zoneId: json["zone_id"]?.toString() ?? "",
      lat: latValue,
      lng: lngValue,
      radius: radiusValue,
      confidence:
          json["confidence_level"]?.toString() ?? json["confidence"]?.toString() ?? "LOW",
      active: json["active"] ?? false,
      source: json["source"]?.toString() ?? "AUTO",
      reason: json["reason"]?.toString(),
      author: json["author"]?.toString(),
    );
  }
}
