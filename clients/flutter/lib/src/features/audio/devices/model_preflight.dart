import '../../../services/audio_preferences.dart';
import '../../../services/native_noise_model_preflight.dart';
import 'state.dart';

extension AudioModelPreflight on AudioDeviceState {
  Future<bool> prepareNoiseModelForCaptureIfNeeded(
    bool Function() active, {
    NoiseSuppressionMode? mode,
    void Function()? onFallback,
  }) => prepareNoiseModelForCapture(
    enabled: (mode ?? captureNoiseOverride) == NoiseSuppressionMode.deepfilter,
    active: active,
    poll: () async {
      await nativeNoise.refresh();
      if (nativeNoise.state.effectiveMode == 'deepfilter' &&
          nativeNoise.state.processedFrames > 0 &&
          (nativeNoise.state.failureReason == null ||
              nativeNoise.state.failureReason!.isEmpty)) {
        return 'active';
      }
      return nativeNoise.state.failureReason;
    },
    fallback: (reason) async {
      await nativeNoise.useFallback(reason, captureApplied: false);
      if (active()) {
        captureNoiseOverride = NoiseSuppressionMode.browser;
        onFallback?.call();
      }
    },
  );
}
