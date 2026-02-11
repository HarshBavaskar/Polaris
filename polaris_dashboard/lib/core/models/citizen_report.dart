class CitizenReport {
  final String reportId;
  final String zoneId;
  final String type;
  final String? level;
  final String? filename;
  final String? filepath;
  final DateTime? timestamp;

  CitizenReport({
    required this.reportId,
    required this.zoneId,
    required this.type,
    this.level,
    this.filename,
    this.filepath,
    this.timestamp,
  });

  factory CitizenReport.fromJson(Map<String, dynamic> json) {
    final rawTs = json["timestamp"];
    return CitizenReport(
      reportId: json["report_id"]?.toString() ?? "",
      zoneId: json["zone_id"]?.toString() ?? "",
      type: json["type"]?.toString() ?? "UNKNOWN",
      level: json["level"]?.toString(),
      filename: json["filename"]?.toString(),
      filepath: json["filepath"]?.toString(),
      timestamp: rawTs == null ? null : DateTime.tryParse(rawTs.toString())?.toLocal(),
    );
  }
}
