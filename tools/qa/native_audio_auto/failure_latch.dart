class FailureLatch {
  String? reason;
  static const _allowed = {
    'processor-underrun',
    'processor-failed',
    'processor-unavailable',
    'unsupported-audio-format',
    'invalid-audio-samples',
    'hook-error',
    'auto-recovery-failed',
    'browser-recovery-failed',
  };
  void observe(String? value) {
    if (reason != null ||
        value == null ||
        value.isEmpty ||
        value == 'awaiting-audio' ||
        value == 'awaiting-model') {
      return;
    }
    reason = _allowed.contains(value) ? value : 'other-native-failure';
  }
}
