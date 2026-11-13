import 'dart:async';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deepfilter_track_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('FlutterWebRTC.Method');

  test('settings recapture waits for the new model before unmute', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final track = TestAudioTrack()..restarted = Completer<void>();
    final blocked = Completer<void>();
    final polling = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getNoiseSuppressionState' &&
              track.restarts.isNotEmpty) {
            if (!polling.isCompleted) polling.complete();
            await blocked.future;
          }
          return {
            'supported': true,
            'effectiveEngine': 'unknown',
            'failureReason': 'awaiting-audio',
          };
        });
    final room = TestRoom(TestParticipant(track));
    final owner = AudioDeviceController(readRoom: () => room)
      ..microphoneMutedIntent = false;
    owner.nativeNoise.debugAllowDeepFilter();
    try {
      final pending = owner.setAudioProcessing(
        const AudioProcessingPreferences(
          noiseSuppressionMode: NoiseSuppressionMode.deepfilter,
        ),
      );
      await polling.future;
      expect(track.muted, true);
      expect(track.unmuteCalls, 0);
      blocked.complete();
      await pending;
      expect(track.unmuteCalls, 1);
      expect(track.currentOptions.noiseSuppression, false);
    } finally {
      owner.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
