import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/audio_preferences.dart';
import '../../../services/voice_processing_platform.dart';
import 'model_preflight.dart';
import 'state.dart';
part 'processing_runtime.dart';
part 'processing_change.dart';
part 'processing_restore.dart';

mixin AudioDeviceProcessing on AudioDeviceState {
  void monitorNativeNoise() => _monitorNativeNoise();
  Future<void> setAudioProcessing(AudioProcessingPreferences next) {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    return nativeNoise.run(() async {
      if (!ticket.isActive ||
          !identical(settings, preferences) ||
          !identical(targetRoom, room) ||
          isDisposed) {
        return;
      }
      await _setAudioProcessing(next);
    });
  }

  Future<AudioProcessingPreferences> prepareNoiseForCapture() async {
    final mode = await nativeNoise.prepare(
      audioProcessing.noiseSuppressionMode,
    );
    captureNoiseOverride = mode;
    if (mode == NoiseSuppressionMode.browser &&
        mode != audioProcessing.noiseSuppressionMode) {
      await nativeNoise.useFallback(
        nativeNoise.state.failureReason ?? 'unsupported',
        unsupported: true,
        captureApplied: false,
      );
    }
    return audioProcessing.copyWith(noiseSuppressionMode: mode);
  }
}
