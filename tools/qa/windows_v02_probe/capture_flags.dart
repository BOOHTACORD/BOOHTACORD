({bool aec, bool agc}) captureFlags(Map<String, String> environment) {
  bool read(String key, bool fallback) {
    final value = environment[key];
    if (value == null) return fallback;
    if (value == '1') return true;
    if (value == '0') return false;
    throw FormatException('Invalid capture flag: $key');
  }

  return (
    aec: read('BOOHTA_PROBE_AEC', true),
    agc: read('BOOHTA_PROBE_AGC', false),
  );
}
