import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter_webrtc/src/native/media_stream_impl.dart';
import 'package:flutter_webrtc/src/native/media_stream_track_impl.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  testWidgets(
    'layout rebuild preserves the current native first-frame generation',
    (tester) async {
      const methods = MethodChannel('FlutterWebRTC.Method');
      const textureEvents = MethodChannel('FlutterWebRTC/Texture42');
      const rtcEvents = MethodChannel('FlutterWebRTC.Event');
      final attachments = <Map<dynamic, dynamic>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(methods, (
        call,
      ) async {
        switch (call.method) {
          case 'initialize':
          case 'videoRendererDispose':
            return null;
          case 'createVideoRenderer':
            return {'textureId': 42};
          case 'videoRendererSetSrcObject':
            attachments.add(call.arguments as Map<dynamic, dynamic>);
            return null;
          default:
            fail('Unexpected native method ${call.method}');
        }
      });
      for (final channel in [textureEvents, rtcEvents]) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => null,
        );
      }
      addTearDown(() {
        for (final channel in [methods, textureEvents, rtcEvents]) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        }
      });
      final renderer = rtc.RTCVideoRenderer();
      await tester.runAsync(renderer.initialize);
      final stream = MediaStreamNative('qa-screen', 'remote');
      final mediaTrack = MediaStreamTrackNative(
        'qa-video',
        'screen',
        'video',
        true,
        'remote',
      );
      final track = RemoteVideoTrack(
        TrackSource.screenShareVideo,
        stream,
        mediaTrack,
      );
      var firstFrames = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: VideoTrackRenderer(
            track,
            cachedRenderer: renderer,
            autoDisposeRenderer: false,
            onFirstFrameRendered: () => firstFrames++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final initialGeneration = attachments.first['sourceGeneration'] as int;
      renderer.eventListener({
        'event': 'didTextureChangeVideoSize',
        'sourceGeneration': initialGeneration,
        'width': 576,
        'height': 1280,
      });
      await tester.pump();
      await tester.pump();
      renderer.eventListener({
        'event': 'didFirstFrameRendered',
        'sourceGeneration': initialGeneration,
      });
      expect(
        firstFrames,
        1,
        reason: 'A resize must not invalidate the frame already uploaded by native WebRTC',
      );
      expect(
        attachments.where((a) => a['streamId'] == 'qa-screen'),
        hasLength(1),
      );
      expect(renderer.videoWidth, 576);
      expect(renderer.videoHeight, 1280);
      final replacement = RemoteVideoTrack(
        TrackSource.screenShareVideo,
        MediaStreamNative('qa-replacement', 'remote'),
        MediaStreamTrackNative(
          'qa-replacement-video',
          'screen',
          'video',
          true,
          'remote',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VideoTrackRenderer(
            replacement,
            cachedRenderer: renderer,
            autoDisposeRenderer: false,
            onFirstFrameRendered: () => firstFrames++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final replacementGeneration = attachments.last['sourceGeneration'] as int;
      expect(replacementGeneration, greaterThan(initialGeneration));
      renderer.eventListener({
        'event': 'didFirstFrameRendered',
        'sourceGeneration': initialGeneration,
      });
      expect(
        firstFrames,
        1,
        reason: 'The replaced source must remain rejected',
      );
      renderer.eventListener({
        'event': 'didFirstFrameRendered',
        'sourceGeneration': replacementGeneration,
      });
      expect(firstFrames, 2);
      expect(
        attachments.where((a) => a['streamId'] == 'qa-replacement'),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(renderer.dispose);
    },
  );
}
