const soundFlags = <String>{
  'enabled',
  'joined',
  'left',
  'started',
  'stopped',
  'allow_custom',
};

void validateSoundChanges(Map<String, dynamic> values) {
  if (values.isEmpty) throw const FormatException('Empty preferences');
  for (final entry in values.entries) {
    if (soundFlags.contains(entry.key) && entry.value is bool) continue;
    if (entry.key == 'volume' &&
        entry.value is int &&
        (entry.value as int) >= 0 &&
        (entry.value as int) <= 100) {
      continue;
    }
    throw const FormatException('Invalid preference');
  }
}

class VoiceSoundSnapshot {
  VoiceSoundSnapshot._(this.revision, this.settings);
  final int revision;
  final Map<String, dynamic> settings;

  factory VoiceSoundSnapshot.parse(dynamic value) {
    if (value is! Map ||
        value['revision'] is! int ||
        (value['revision'] as int) < 0 ||
        value['settings'] is! Map) {
      throw const FormatException('Invalid snapshot');
    }
    final raw = value['settings'] as Map;
    final result = <String, dynamic>{};
    for (final key in soundFlags) {
      if (raw[key] is! bool) throw const FormatException('Invalid sound flag');
      result[key] = raw[key];
    }
    result['volume'] = raw['volume'];
    validateSoundChanges(result);
    return VoiceSoundSnapshot._(
      value['revision'] as int,
      Map.unmodifiable(result),
    );
  }
}
