DateTime? notificationUtc(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(Z|[+]00:00)$',
  ).firstMatch(value);
  final time = DateTime.tryParse(value);
  if (match == null || time == null || !time.isUtc || time.year < 1) {
    return null;
  }
  final parts = [
    time.year,
    time.month,
    time.day,
    time.hour,
    time.minute,
    time.second,
  ];
  for (var i = 0; i < parts.length; i++) {
    if (parts[i] != int.parse(match.group(i + 1)!)) return null;
  }
  return time;
}
