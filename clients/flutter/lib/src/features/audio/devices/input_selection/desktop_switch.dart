import 'package:livekit_client/livekit_client.dart';

import '../../../../services/audio_preferences.dart';
import '../model_preflight.dart';
import '../state.dart';

mixin AudioInputDesktopSwitch on AudioDeviceState {
  Future<void> switchDesktopInput(
    LocalAudioTrack track,
    MediaDevice device,
    bool Function() current, {
    required Future<void> Function() selectDevice,
  }) async {
    final deep = captureNoiseOverride == NoiseSuppressionMode.deepfilter;
    final resume = deep && !track.muted && !microphoneMutedIntent;
    try {
      if (deep) await track.mute(stopOnMute: false);
      await nativeNoise.reset();
      if (!current()) return;
      await selectDevice();
      if (!current()) return;
      track.currentOptions = track.currentOptions.copyWith(
        deviceId: device.deviceId,
      );
      if (!resume || microphoneMutedIntent) return;
      var fellBack = false;
      if (!await prepareNoiseModelForCaptureIfNeeded(
        () => current() && !microphoneMutedIntent,
        onFallback: () => fellBack = true,
      )) {
        return;
      }
      if (fellBack) {
        await track.restartTrack(
          track.currentOptions.copyWith(noiseSuppression: true),
        );
        await track.disable();
        if (!current()) return;
        nativeNoise.confirmFallback(
          nativeNoise.state.failureReason ?? 'unsupported',
        );
      }
      if (current() && !microphoneMutedIntent) {
        await track.unmute(stopOnMute: false);
      }
    } catch (_) {
      if (deep && current()) {
        microphoneMutedIntent = true;
        await track.mute(stopOnMute: false);
        nativeNoise.failMuted('input-switch-failed');
      }
      rethrow;
    }
  }
}
