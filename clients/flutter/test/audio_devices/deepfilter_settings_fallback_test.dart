import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deepfilter_track_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('failure after recapture restores WebRTC before unmuting', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const channel = MethodChannel('FlutterWebRTC.Method');
    final track = TestAudioTrack();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => {
            'supported': true,
            'effectiveEngine': 'unknown',
            'failureReason':
                call.method == 'getNoiseSuppressionState' &&
                    track.restarts.isNotEmpty
                ? 'processor-failed'
                : 'awaiting-audio',
          },
        );
    final room = TestRoom(TestParticipant(track));
    final owner = AudioDeviceController(readRoom: () => room)
      ..microphoneMutedIntent = false;
    owner.nativeNoise.debugAllowDeepFilter();
    try {
      await owner.setAudioProcessing(
        const AudioProcessingPreferences(
          noiseSuppressionMode: NoiseSuppressionMode.deepfilter,
        ),
      );
      expect(track.restarts.length, 2);
      expect(track.restarts[0].noiseSuppression, false);
      expect(track.restarts[1].noiseSuppression, true);
      expect(track.unmuteCalls, 1);
      expect(owner.captureNoiseOverride, NoiseSuppressionMode.browser);
      expect(owner.nativeNoise.state.effectiveMode, 'browser');
    } finally {
      owner.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
