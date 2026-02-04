class HistoricalIncident {
  final double lat;
  final double lng;
  final String date;

  HistoricalIncident({
    required this.lat,
    required this.lng,
    required this.date,
  });

  factory HistoricalIncident.fromJson(Map<String, dynamic> json) {
    return HistoricalIncident(
      lat: json["lat"].toDouble(),
      lng: json["lng"].toDouble(),
      date: json["date"] ?? "",
    );
  }
}
