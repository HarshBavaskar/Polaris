class HelpRequest {
  final String id;
  final String category;
  final String contactNumber;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  const HelpRequest({
    required this.id,
    required this.category,
    required this.contactNumber,
    required this.createdAt,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'category': category,
    'contact_number': contactNumber,
    'lat': lat,
    'lng': lng,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  static HelpRequest? fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final String id = value['id']?.toString() ?? '';
    final String category = value['category']?.toString() ?? '';
    final String contact = value['contact_number']?.toString() ?? '';
    final DateTime? createdAt = DateTime.tryParse(
      value['created_at']?.toString() ?? '',
    );
    if (id.isEmpty ||
        category.isEmpty ||
        contact.isEmpty ||
        createdAt == null) {
      return null;
    }
    return HelpRequest(
      id: id,
      category: category,
      contactNumber: contact,
      lat: (value['lat'] as num?)?.toDouble(),
      lng: (value['lng'] as num?)?.toDouble(),
      createdAt: createdAt,
    );
  }
}
