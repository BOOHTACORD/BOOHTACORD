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
  for (final testCase in [(true, false), (true, true), (false, false)]) {
    final (eligible, muted) = testCase;
    test('Auto runtime fallback measured=$eligible muted=$muted', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const channel = MethodChannel('FlutterWebRTC.Method');
      var engine = 'browser', failure = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getNoiseSuppressionCapabilities') {
              return {
                'deepfilterModelId': 'deepfilternet3-research-d375b2d',
                'rnnoiseModelId': 'rnnoise-stock-v0.2',
                'rnnoisePreflightState': eligible ? 2 : 3,
                'rnnoiseP95Us': 200,
                'rnnoiseMaxUs': 300,
              };
            }
            if (call.method == 'setNoiseSuppressionEngine') {
              engine = (call.arguments as Map)['engine'] as String;
            }
            return {
              'supported': true,
              'effectiveEngine': engine,
              'processedFrames': 3,
              'failureReason': engine == 'deepfilter' && failure
                  ? 'processor-underrun'
                  : '',
            };
          });
      final track = TestAudioTrack()
        ..restarted = Completer<void>()
        ..currentOptions = const AudioCaptureOptions(
          echoCancellation: true,
          autoGainControl: false,
          noiseSuppression: false,
        );
      final room = TestRoom(TestParticipant(track));
      final owner = AudioDeviceController(readRoom: () => room)
        ..microphoneMutedIntent = muted
        ..audioProcessing = const AudioProcessingPreferences(
          noiseSuppressionMode: NoiseSuppressionMode.auto,
          echoCancellation: true,
          autoGainControl: false,
        );
      owner.nativeNoise.debugAllowDeepFilter();
      try {
        expect(
          (await owner.prepareNoiseForCapture()).noiseSuppressionMode,
          NoiseSuppressionMode.deepfilter,
        );
        failure = true;
        owner.monitorNativeNoise();
        await track.restarted!.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          owner.captureNoiseOverride,
          eligible
              ? NoiseSuppressionMode.rnnoise
              : NoiseSuppressionMode.browser,
        );
        expect(
          owner.nativeNoise.state.requestedMode,
          NoiseSuppressionMode.auto,
        );
        expect(
          owner.nativeNoise.state.effectiveMode,
          eligible ? 'rnnoise' : 'browser',
        );
        expect(track.currentOptions.noiseSuppression, !eligible);
        expect(track.currentOptions.echoCancellation, true);
        expect(track.currentOptions.autoGainControl, false);
        expect(track.unmuteCalls, muted ? 0 : 1);
        expect(owner.microphoneMutedIntent, muted);
      } finally {
        owner.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
