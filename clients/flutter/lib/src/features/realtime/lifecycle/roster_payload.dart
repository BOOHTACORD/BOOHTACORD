final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _date = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]\d{2}:\d{2})$',
  caseSensitive: false,
);

bool isRosterKind(Object? kind) =>
    kind == 'voice.roster.snapshot' || kind == 'voice.roster.unavailable';
bool _keys(Map<String, dynamic> value, List<String> names) =>
    value.length == names.length && names.every(value.containsKey);
bool _id(Object? value) => value is String && _uuid.hasMatch(value);

bool validRealtimeTimestamp(Object? value) {
  if (value is! String) return false;
  final match = _date.firstMatch(value);
  if (match == null || DateTime.tryParse(value) == null) return false;
  final year = int.parse(match[1]!),
      month = int.parse(match[2]!),
      day = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return false;
  if (int.parse(match[4]!) > 23 ||
      int.parse(match[5]!) > 59 ||
      int.parse(match[6]!) > 59) {
    return false;
  }
  final zone = match[7]!;
  return zone.toUpperCase() == 'Z' ||
      (int.parse(zone.substring(1, 3)) <= 23 &&
          int.parse(zone.substring(4, 6)) <= 59);
}

bool _participants(Object? value) {
  if (value is! List) return false;
  final seen = <String>{};
  for (final item in value) {
    if (item is! Map<String, dynamic> ||
        !_keys(item, [
          'account_id',
          'display_name',
          'screen_sharing',
          'microphone_muted',
        ])) {
      return false;
    }
    final account = item['account_id'], name = item['display_name'];
    if (!_id(account) ||
        !seen.add((account as String).toLowerCase()) ||
        name is! String ||
        name.runes.isEmpty ||
        name.runes.length > 64 ||
        item['screen_sharing'] is! bool ||
        item['microphone_muted'] is! bool) {
      return false;
    }
  }
  return true;
}

bool validRosterPayload(Object? kind, Object? value) {
  if (value is! Map<String, dynamic>) return false;
  if (kind == 'voice.roster.unavailable') {
    return _keys(value, ['version', 'code']) &&
        value['version'] == 1 &&
        value['code'] == 'temporarily_unavailable';
  }
  if (kind != 'voice.roster.snapshot' ||
      !_keys(value, [
        'version',
        'generation',
        'revision',
        'observed_at',
        'channels',
      ])) {
    return false;
  }
  final revision = value['revision'], channels = value['channels'];
  if (value['version'] != 1 ||
      !_id(value['generation']) ||
      revision is! num ||
      !revision.isFinite ||
      revision != revision.truncateToDouble() ||
      revision < 1 ||
      revision > 9007199254740991 ||
      !validRealtimeTimestamp(value['observed_at']) ||
      channels is! List) {
    return false;
  }
  final seen = <String>{};
  for (final channel in channels) {
    if (channel is! Map<String, dynamic> ||
        !_keys(channel, ['channel_id', 'participants'])) {
      return false;
    }
    final channelID = channel['channel_id'];
    if (!_id(channelID) ||
        !seen.add((channelID as String).toLowerCase()) ||
        !_participants(channel['participants'])) {
      return false;
    }
  }
  return true;
}
