import 'dart:async';

import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('FlutterWebRTC.Method');

  test('microphone is not published before reset model is ready', () async {
    final pollStarted = Completer<void>(), ready = Completer<void>();
    var reset = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'resetNoiseSuppression') reset = true;
          if (call.method == 'getNoiseSuppressionState' && reset) {
            if (!pollStarted.isCompleted) pollStarted.complete();
            await ready.future;
          }
          return {
            'supported': true,
            'effectiveEngine': 'unknown',
            'failureReason': 'awaiting-audio',
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final harness = VoiceHarness();
    addTearDown(harness.dispose);
    harness.audio.nativeNoise.debugAllowDeepFilter();
    harness.owner.room = harness.room;
    harness.audio.audioProcessing = const AudioProcessingPreferences(
      noiseSuppressionMode: NoiseSuppressionMode.deepfilter,
    );
    final enabling = harness.owner.applyMicrophoneMuted(false);
    await pollStarted.future;
    expect(harness.room.localParticipant.enabled, isEmpty);
    expect(harness.audio.captureOptions.noiseSuppression, false);
    ready.complete();
    await harness.room.localParticipant.started.future;
    expect(harness.room.localParticipant.enabled, [true]);
    harness.room.localParticipant.capture.complete();
    expect(await enabling, true);
  });

  test(
    'model failure switches constraints to browser before publication',
    () async {
      var reset = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'resetNoiseSuppression') reset = true;
            return {
              'supported': true,
              'effectiveEngine': 'unknown',
              'failureReason':
                  call.method == 'getNoiseSuppressionState' && reset
                  ? 'processor-failed'
                  : 'awaiting-audio',
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final harness = VoiceHarness();
      addTearDown(harness.dispose);
      harness.audio.nativeNoise.debugAllowDeepFilter();
      harness.owner.room = harness.room;
      harness.audio.audioProcessing = const AudioProcessingPreferences(
        noiseSuppressionMode: NoiseSuppressionMode.deepfilter,
      );
      final enabling = harness.owner.applyMicrophoneMuted(false);
      await harness.room.localParticipant.started.future;
      expect(harness.audio.captureNoiseOverride, NoiseSuppressionMode.browser);
      expect(harness.audio.captureOptions.noiseSuppression, true);
      harness.room.localParticipant.capture.complete();
      expect(await enabling, true);
      expect(harness.audio.nativeNoise.state.effectiveMode, 'browser');
    },
  );
}
