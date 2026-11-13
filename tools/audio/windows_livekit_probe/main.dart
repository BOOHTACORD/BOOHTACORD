import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

import 'metrics.dart';

const channel = MethodChannel('FlutterWebRTC.Method');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(home: Scaffold(body: Text('Local audio diagnostics'))),
  );
  final result = <String, Object?>{};
  final sender = lk.Room(), receiver = lk.Room();
  var stage = 'start', subscribed = false;
  final listener = receiver.createListener();
  listener.on<lk.TrackSubscribedEvent>((event) {
    if (event.track is lk.RemoteAudioTrack) {
      subscribed = true;
      unawaited(rtc.Helper.setVolume(0, event.track.mediaStreamTrack));
    }
  });
  try {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    stage = 'receiver-connect';
    await receiver
        .connect(
          'ws://127.0.0.1:17880',
          Platform.environment['BOOHTA_PROBE_RECEIVER_TOKEN']!,
        )
        .timeout(const Duration(seconds: 20));
    stage = 'sender-connect';
    await sender
        .connect(
          'ws://127.0.0.1:17880',
          Platform.environment['BOOHTA_PROBE_SENDER_TOKEN']!,
        )
        .timeout(const Duration(seconds: 20));
    stage = 'model-prepare';
    var state = await channel.invokeMapMethod<String, dynamic>(
      'setNoiseSuppressionEngine',
      {'engine': 'deepfilter'},
    );
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (state?['failureReason'] == 'awaiting-model' &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      state = await channel.invokeMapMethod<String, dynamic>(
        'getNoiseSuppressionState',
      );
    }
    result['prepared'] = state;
    if (state?['failureReason'] != 'awaiting-audio')
      throw StateError('model-not-ready');
    stage = 'microphone-publish';
    final pub = await sender.localParticipant!.setMicrophoneEnabled(
      true,
      audioCaptureOptions: const lk.AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: false,
      ),
    );
    result['published'] = pub != null;
    stage = 'media';
    await Future<void>.delayed(const Duration(seconds: 10));
    result['subscribed'] = subscribed;
    result.addAll(await inboundCounters(receiver));
    state = await channel.invokeMapMethod<String, dynamic>(
      'getNoiseSuppressionState',
    );
    result['capture'] = state;
    result['success'] =
        pub != null &&
        subscribed &&
        (result['receivedPackets'] as int) > 0 &&
        state?['effectiveEngine'] == 'deepfilter' &&
        (state?['processedFrames'] as int? ?? 0) > 0 &&
        (state?['fallbackFrames'] as int? ?? 0) == 0;
  } catch (e) {
    result['stage'] = stage;
    result['errorType'] = e.runtimeType.toString();
    result['success'] = false;
  } finally {
    try {
      await sender.localParticipant?.setMicrophoneEnabled(false);
    } catch (_) {}
    try {
      await sender.disconnect();
    } catch (_) {}
    try {
      await receiver.disconnect();
    } catch (_) {}
    await listener.dispose();
    try {
      await channel.invokeMethod<Object?>('setNoiseSuppressionEngine', {
        'engine': 'browser',
      });
    } catch (_) {}
    final path = Platform.environment['BOOHTA_AUDIO_PROBE_RESULT'];
    if (path != null && path.isNotEmpty)
      await File(path).writeAsString(jsonEncode(result));
    exit(result['success'] == true ? 0 : 1);
  }
}
