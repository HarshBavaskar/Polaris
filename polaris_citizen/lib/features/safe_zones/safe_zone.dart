class SafeZone {
  final String zoneId;
  final double lat;
  final double lng;
  final int radius;
  final String confidence;
  final bool active;
  final String source;

  SafeZone({
    required this.zoneId,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.confidence,
    required this.active,
    required this.source,
  });

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    return SafeZone(
      zoneId: json['zone_id']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      radius: (json['radius'] as num?)?.toInt() ?? 300,
      confidence:
          json['confidence_level']?.toString() ??
          json['confidence']?.toString() ??
          'LOW',
      active: json['active'] == true,
      source: json['source']?.toString() ?? 'AUTO',
    );
  }
}
