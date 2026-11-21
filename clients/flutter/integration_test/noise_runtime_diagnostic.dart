import 'package:boohtacord_desktop/src/services/native_noise_suppression_state.dart';

const _statuses = {
  'idle',
  'initializing',
  'active',
  'fallback',
  'unsupported',
  'error',
};
const _engines = {'unknown', 'off', 'browser', 'rnnoise', 'deepfilter'};
const _reasons = {
  'awaiting-audio',
  'awaiting-model',
  'auto-recovery-failed',
  'browser-recovery-failed',
  'hardware-noise-suppression-active',
  'hook-error',
  'input-switch-failed',
  'invalid-audio-samples',
  'processor-failed',
  'processor-unavailable',
  'processor-underrun',
  'rollback-failed',
  'unsupported',
  'unsupported-audio-format',
};

String noiseRuntimeDiagnostic(NativeNoiseSuppressionState state) {
  final status = _statuses.contains(state.status) ? state.status : 'other';
  final engine = _engines.contains(state.effectiveMode)
      ? state.effectiveMode
      : 'other';
  final reason = state.failureReason == null || state.failureReason!.isEmpty
      ? 'none'
      : _reasons.contains(state.failureReason)
      ? state.failureReason
      : 'other';
  return 'status=$status engine=$engine reason=$reason '
      'processed=${state.processedFrames} fallback=${state.fallbackFrames} '
      'rate=${state.sampleRate} channels=${state.channels}';
}
