class RescueTeam {
  final String teamId;
  final String name;
  final int membersCount;
  final String status;
  final double? lat;
  final double? lng;
  final String? contactNumber;
  final String? assignedRequestId;
  final DateTime? updatedAt;
  final DateTime? lastNotifiedAt;

  RescueTeam({
    required this.teamId,
    required this.name,
    required this.membersCount,
    required this.status,
    this.lat,
    this.lng,
    this.contactNumber,
    this.assignedRequestId,
    this.updatedAt,
    this.lastNotifiedAt,
  });

  factory RescueTeam.fromJson(Map<String, dynamic> json) {
    return RescueTeam(
      teamId: json['team_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Team',
      membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString().toUpperCase() ?? 'AVAILABLE',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      contactNumber: json['contact_number']?.toString(),
      assignedRequestId: json['assigned_request_id']?.toString(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toLocal(),
      lastNotifiedAt: DateTime.tryParse(
        json['last_notified_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}
