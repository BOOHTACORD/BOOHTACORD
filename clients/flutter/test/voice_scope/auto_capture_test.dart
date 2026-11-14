import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('initial Auto capture confirms the selected browser fallback', () async {
    const channel = MethodChannel('FlutterWebRTC.Method');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => {'supported': true, 'effectiveEngine': 'browser'},
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final harness = VoiceHarness();
    addTearDown(harness.dispose);
    harness.owner.room = harness.room;
    harness.audio.audioProcessing = const AudioProcessingPreferences(
      noiseSuppressionMode: NoiseSuppressionMode.auto,
    );
    final enabling = harness.owner.applyMicrophoneMuted(false);
    await harness.room.localParticipant.started.future;
    expect(harness.audio.captureOptions.noiseSuppression, isTrue);
    expect(harness.audio.nativeNoise.state.effectiveMode, 'unknown');
    harness.room.localParticipant.capture.complete();
    expect(await enabling, isTrue);
    expect(
      harness.audio.nativeNoise.state.requestedMode,
      NoiseSuppressionMode.auto,
    );
    expect(harness.audio.nativeNoise.state.effectiveMode, 'browser');
    expect(harness.audio.nativeNoise.state.status, 'unsupported');
  });

  test(
    'Auto cannot publish while AFK microphone permission is denied',
    () async {
      final harness = VoiceHarness();
      addTearDown(harness.dispose);
      harness.owner.room = harness.room;
      harness.owner.microphoneAllowed = false;
      harness.audio.audioProcessing = const AudioProcessingPreferences(
        noiseSuppressionMode: NoiseSuppressionMode.auto,
      );
      expect(await harness.owner.applyMicrophoneMuted(false), isFalse);
      expect(harness.room.localParticipant.enabled, isEmpty);
      expect(harness.owner.microphoneMuted, isTrue);
      expect(harness.audio.microphoneMutedIntent, isTrue);
    },
  );
}
