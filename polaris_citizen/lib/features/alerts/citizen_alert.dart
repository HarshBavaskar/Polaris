class CitizenAlert {
  final String id;
  final String severity;
  final String channel;
  final String message;
  final DateTime timestamp;

  const CitizenAlert({
    required this.id,
    required this.severity,
    required this.channel,
    required this.message,
    required this.timestamp,
  });

  factory CitizenAlert.fromJson(Map<String, dynamic> json) {
    final String rawSeverity = json['severity']?.toString() ?? 'UNKNOWN';
    final String rawChannel = json['channel']?.toString() ?? 'UNKNOWN';
    final String rawMessage = json['message']?.toString() ?? '';
    final String rawTimestamp =
        json['timestamp']?.toString() ??
        json['created_at']?.toString() ??
        DateTime.now().toUtc().toIso8601String();

    final DateTime parsedTimestamp =
        DateTime.tryParse(rawTimestamp)?.toLocal() ?? DateTime.now().toLocal();

    final String rawId = json['_id']?.toString() ?? '';
    final String computedId = rawId.isNotEmpty
        ? rawId
        : '${parsedTimestamp.millisecondsSinceEpoch}-${rawSeverity.toUpperCase()}-${rawMessage.hashCode}';

    return CitizenAlert(
      id: computedId,
      severity: rawSeverity.toUpperCase(),
      channel: rawChannel,
      message: rawMessage,
      timestamp: parsedTimestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_id': id,
      'severity': severity,
      'channel': channel,
      'message': message,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }
}
