import 'audio_preferences.dart';

class NativeNoiseSuppressionState {
  const NativeNoiseSuppressionState({
    this.requestedMode = NoiseSuppressionMode.browser,
    this.effectiveMode = 'unknown',
    this.status = 'idle',
    this.failureReason,
    this.processedFrames = 0,
    this.fallbackFrames = 0,
    this.sampleRate,
    this.channels,
    this.rnnoiseModelId,
    this.deepfilterModelId,
  });
  final NoiseSuppressionMode requestedMode;
  final String effectiveMode, status;
  final String? failureReason;
  final int processedFrames, fallbackFrames;
  final int? sampleRate, channels;
  final String? rnnoiseModelId, deepfilterModelId;
}
