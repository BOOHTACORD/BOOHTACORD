import 'dart:async';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

import 'deepfilter_track_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('input switch stays muted until new native model generation is ready', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const channel = MethodChannel('FlutterWebRTC.Method');
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
    final track = TestAudioTrack();
    final room = TestRoom(TestParticipant(track));
    final owner = AudioDeviceController(readRoom: () => room)
      ..microphoneMutedIntent = false
      ..audioProcessing = const AudioProcessingPreferences(
        noiseSuppressionMode: NoiseSuppressionMode.deepfilter,
      )
      ..captureNoiseOverride = NoiseSuppressionMode.deepfilter
      ..audioInputDevices = const [
        MediaDevice('mic-2', 'Mic', 'audioinput', 'g'),
      ];
    owner.nativeNoise.debugAllowDeepFilter();
    try {
      await owner.nativeNoise.prepare(NoiseSuppressionMode.deepfilter);
      const device = MediaDevice('mic-2', 'Mic', 'audioinput', 'g');
      final pending = owner.switchDesktopInput(
        track,
        device,
        () => true,
        selectDevice: () async {
          room.inputs.add(device);
        },
      );
      final didPoll = await Future.any([
        pollStarted.future.then((_) => true),
        pending.then((_) => false),
      ]);
      expect(
        didPoll,
        true,
        reason:
            'switch error: ${owner.audioSettingsError}; inputs: ${room.inputs.length}',
      );
      expect(track.muted, true);
      expect(track.unmuteCalls, 0);
      ready.complete();
      await pending;
      expect(track.unmuteCalls, 1);
      expect(track.currentOptions.deviceId, 'mic-2');
    } finally {
      if (!ready.isCompleted) ready.complete();
      owner.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
