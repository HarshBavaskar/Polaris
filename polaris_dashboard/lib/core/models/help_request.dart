class HelpRequest {
  final String requestId;
  final String category;
  final String contactNumber;
  final double? lat;
  final double? lng;
  final String status;
  final String? assignedTeamId;
  final DateTime? createdAt;
  final DateTime? assignedAt;

  HelpRequest({
    required this.requestId,
    required this.category,
    required this.contactNumber,
    required this.status,
    this.lat,
    this.lng,
    this.assignedTeamId,
    this.createdAt,
    this.assignedAt,
  });

  factory HelpRequest.fromJson(Map<String, dynamic> json) {
    return HelpRequest(
      requestId: json['request_id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      contactNumber: json['contact_number']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      status: json['status']?.toString().toUpperCase() ?? 'OPEN',
      assignedTeamId: json['assigned_team_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
      assignedAt: DateTime.tryParse(json['assigned_at']?.toString() ?? '')?.toLocal(),
    );
  }
}
