class SafeZone {
  final String zoneId;
  final double lat;
  final double lng;
  final int radius;
  final String confidence;
  final bool active;
  final String source;
  final String? area;
  final String? pincode;
  final DateTime? lastVerified;

  SafeZone({
    required this.zoneId,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.confidence,
    required this.active,
    required this.source,
    this.area,
    this.pincode,
    this.lastVerified,
  });

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      return DateTime.tryParse(value.toString());
    }

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
      area: json['area']?.toString() ?? json['locality']?.toString(),
      pincode: json['pincode']?.toString(),
      lastVerified:
          parseDate(json['last_verified']) ??
          parseDate(json['updated_at']) ??
          parseDate(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'zone_id': zoneId,
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'confidence_level': confidence,
      'active': active,
      'source': source,
      if (area != null) 'area': area,
      if (pincode != null) 'pincode': pincode,
      if (lastVerified != null)
        'last_verified': lastVerified!.toUtc().toIso8601String(),
    };
  }
}
