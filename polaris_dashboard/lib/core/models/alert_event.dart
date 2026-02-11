class AlertEvent {
  final String severity;
  final String channel;
  final String message;
  final DateTime timestamp;

  AlertEvent({
    required this.severity,
    required this.channel,
    required this.message,
    required this.timestamp,
  });

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    return AlertEvent(
      severity: json["severity"] ?? "UNKNOWN",
      channel: json["channel"] ?? "UNKNOWN",
      message: json["message"] ?? "",
      timestamp: DateTime.parse(json["timestamp"]).toLocal(),
    );
  }
}
