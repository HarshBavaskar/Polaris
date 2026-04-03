DateTime? parseTimestampToLocal(dynamic value) {
  if (value == null) return null;

  final String raw = value.toString().trim();
  if (raw.isEmpty) return null;

  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;

  final bool hasExplicitTimezone =
      raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);

  if (hasExplicitTimezone) {
    return parsed.toLocal();
  }

  // Backend timestamps are typically emitted without a timezone suffix even
  // though the hosting environment uses UTC. Treat naive values as UTC so the
  // citizen app shows correct relative time on the device.
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  ).toLocal();
}
