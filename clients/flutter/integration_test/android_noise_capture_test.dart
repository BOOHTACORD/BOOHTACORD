import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android RNNoise processes microphone frames over a loopback call',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      await tester.runAsync(() async {
        await rtc.WebRTC.initialize(
          options: {'androidUseHardwareNoiseSuppression': false},
        );
        const channel = MethodChannel('FlutterWebRTC.Method');
        final pending = await channel.invokeMapMethod<String, dynamic>(
          'setNoiseSuppressionEngine',
          {'engine': 'rnnoise'},
        );
        expect(pending?['supported'], isTrue, reason: '$pending');
        final left = await rtc.createPeerConnection({});
        final right = await rtc.createPeerConnection({});
        final stream = await rtc.navigator.mediaDevices.getUserMedia({
          'audio': {'noiseSuppression': false, 'echoCancellation': true},
          'video': false,
        });
        try {
          left.onIceCandidate = (candidate) => right.addCandidate(candidate);
          right.onIceCandidate = (candidate) => left.addCandidate(candidate);
          for (final track in stream.getAudioTracks()) {
            await left.addTrack(track, stream);
          }
          final offer = await left.createOffer();
          await left.setLocalDescription(offer);
          await right.setRemoteDescription(offer);
          final answer = await right.createAnswer();
          await right.setLocalDescription(answer);
          await left.setRemoteDescription(answer);
          Map<String, dynamic>? state;
          for (var i = 0; i < 60; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            state = await channel.invokeMapMethod<String, dynamic>(
              'getNoiseSuppressionState',
            );
            if ((state?['processedFrames'] as int? ?? 0) > 0) break;
          }
          expect(state?['effectiveEngine'], 'rnnoise', reason: '$state');
          expect(state?['processedFrames'], greaterThan(0), reason: '$state');
          expect(state?['failureReason'], '', reason: '$state');
        } finally {
          for (final track in stream.getTracks()) {
            await track.stop();
          }
          await stream.dispose();
          await left.close();
          await right.close();
        }
      });
    },
  );
}
