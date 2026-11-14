import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deepfilter_track_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final engine in [
    NoiseSuppressionMode.rnnoise,
    NoiseSuppressionMode.deepfilter,
  ]) {
    test('Auto keeps ${engine.name} during settings recapture', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const channel = MethodChannel('FlutterWebRTC.Method');
      final engines = <String>[];
      final track = TestAudioTrack();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'setNoiseSuppressionEngine') {
              engines.add((call.arguments as Map)['engine'] as String);
            }
            return {
              'supported': true,
              'effectiveEngine': engine.name,
              'processedFrames': 3,
            };
          });
      final room = TestRoom(TestParticipant(track));
      final owner = AudioDeviceController(readRoom: () => room)
        ..microphoneMutedIntent = false;
      owner.nativeNoise.debugAllowDeepFilter();
      owner.nativeNoise.debugSelectAutoEngine(engine);
      try {
        await owner.setAudioProcessing(
          const AudioProcessingPreferences(
            noiseSuppressionMode: NoiseSuppressionMode.auto,
          ),
        );
        expect(engines, [engine.name]);
        expect(owner.captureNoiseOverride, engine);
        expect(
          owner.nativeNoise.state.requestedMode,
          NoiseSuppressionMode.auto,
        );
        expect(track.currentOptions.noiseSuppression, false);
        expect(track.unmuteCalls, 1);
      } finally {
        owner.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
