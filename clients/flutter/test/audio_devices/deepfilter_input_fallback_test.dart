import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

import 'deepfilter_track_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'failed model restarts with WebRTC before microphone is unmuted',
    () async {
      const channel = MethodChannel('FlutterWebRTC.Method');
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
      final track = TestAudioTrack();
      final room = TestRoom(TestParticipant(track));
      final owner = AudioDeviceController(readRoom: () => room)
        ..microphoneMutedIntent = false
        ..audioProcessing = const AudioProcessingPreferences(
          noiseSuppressionMode: NoiseSuppressionMode.deepfilter,
        )
        ..captureNoiseOverride = NoiseSuppressionMode.deepfilter;
      owner.nativeNoise.debugAllowDeepFilter();
      try {
        await owner.nativeNoise.prepare(NoiseSuppressionMode.deepfilter);
        const device = MediaDevice('mic-2', 'Mic', 'audioinput', 'g');
        await owner.switchDesktopInput(
          track,
          device,
          () => true,
          selectDevice: () async {},
        );
        expect(track.restarts.length, 1);
        expect(track.restarts.single.noiseSuppression, true);
        expect(track.restarts.single.deviceId, 'mic-2');
        expect(track.unmuteCalls, 1);
        expect(owner.captureNoiseOverride, NoiseSuppressionMode.browser);
        expect(owner.nativeNoise.state.effectiveMode, 'browser');
      } finally {
        owner.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
  );
}
