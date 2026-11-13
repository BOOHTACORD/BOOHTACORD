part of 'processing.dart';

extension AudioProcessingRestore on AudioDeviceState {
  Future<void> _restoreNoiseProcessing(
    Object? candidate,
    AudioProcessingPreferences previous,
    NoiseSuppressionMode? previousOverride,
    bool Function() current,
  ) async {
    final prepared = await nativeNoise.prepare(previous.noiseSuppressionMode);
    if (!current()) return;
    var mode = prepared == NoiseSuppressionMode.browser
        ? prepared
        : previousOverride ?? prepared;
    if (mode == NoiseSuppressionMode.browser &&
        previous.noiseSuppressionMode != mode) {
      await nativeNoise.useFallback(
        nativeNoise.state.failureReason ?? 'restored-previous-fallback',
        captureApplied: false,
      );
    }
    await applyMicrophoneControls(agc: previous.autoGainControl);
    if (candidate is! LocalAudioTrack || !current()) return;
    await _applyTrackProcessing(
      candidate,
      previous.copyWith(noiseSuppressionMode: mode),
    );
    var fellBack = false;
    if (!await prepareNoiseModelForCaptureIfNeeded(
      current,
      mode: mode,
      onFallback: () => fellBack = true,
    )) {
      return;
    }
    if (fellBack) {
      mode = NoiseSuppressionMode.browser;
      await _applyTrackProcessing(
        candidate,
        previous.copyWith(noiseSuppressionMode: mode),
      );
    }
    if (!current()) return;
    captureNoiseOverride = mode;
    if (mode != previous.noiseSuppressionMode &&
        mode == NoiseSuppressionMode.browser) {
      nativeNoise.confirmFallback(
        nativeNoise.state.failureReason ?? 'unsupported',
      );
    }
    if (!microphoneMutedIntent) await candidate.unmute(stopOnMute: false);
  }
}
