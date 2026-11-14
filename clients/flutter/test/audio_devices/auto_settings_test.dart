import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deepfilter_track_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final muted in [false, true]) {
    test('Auto uses browser capture and preserves muted=$muted', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const channel = MethodChannel('FlutterWebRTC.Method');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'setNoiseSuppressionEngine') {
              calls.add((call.arguments as Map)['engine'] as String);
            }
            return {'supported': true, 'effectiveEngine': 'browser'};
          });
      final track = TestAudioTrack();
      final room = TestRoom(TestParticipant(track));
      final owner = AudioDeviceController(readRoom: () => room)
        ..microphoneMutedIntent = muted;
      try {
        await owner.setAudioProcessing(
          const AudioProcessingPreferences(
            noiseSuppressionMode: NoiseSuppressionMode.auto,
          ),
        );
        expect(track.restarts.single.noiseSuppression, isTrue);
        expect(track.unmuteCalls, muted ? 0 : 1);
        expect(
          owner.audioProcessing.noiseSuppressionMode,
          NoiseSuppressionMode.auto,
        );
        expect(owner.captureNoiseOverride, NoiseSuppressionMode.browser);
        expect(
          owner.nativeNoise.state.requestedMode,
          NoiseSuppressionMode.auto,
        );
        expect(calls, isNotEmpty);
        expect(calls.every((value) => value == 'browser'), isTrue);
      } finally {
        owner.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
