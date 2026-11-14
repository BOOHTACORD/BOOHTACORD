import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

import 'packet_delta.dart';
import 'reports.dart';
import 'support.dart';

const channel = MethodChannel('FlutterWebRTC.Method');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(home: Scaffold(body: Text('Local audio diagnostics'))),
  );
  final result = <String, Object?>{};
  final sender = lk.Room(), receiver = lk.Room();
  var stage = 'start', subscriptions = 0;
  final listener = receiver.createListener();
  listener.on<lk.TrackSubscribedEvent>((event) {
    if (event.track is lk.RemoteAudioTrack) {
      subscriptions++;
      unawaited(rtc.Helper.setVolume(0, event.track.mediaStreamTrack));
    }
  });
  try {
    await requireResearchMarker();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    stage = 'connect';
    await receiver
        .connect(
          'ws://127.0.0.1:17880',
          Platform.environment['BOOHTA_PROBE_RECEIVER_TOKEN']!,
        )
        .timeout(const Duration(seconds: 20));
    await sender
        .connect(
          'ws://127.0.0.1:17880',
          Platform.environment['BOOHTA_PROBE_SENDER_TOKEN']!,
        )
        .timeout(const Duration(seconds: 20));
    stage = 'publish';
    final pub = await sender.localParticipant!.setMicrophoneEnabled(
      true,
      audioCaptureOptions: const lk.AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: false,
      ),
    );
    if (pub == null) throw StateError('publication-missing');
    final states = <Map<String, dynamic>>[];
    final deltas = <int>[];
    result['states'] = states;
    result['packetDeltas'] = deltas;
    var previous = 0;
    for (final mode in ['rnnoise', 'deepfilter', 'rnnoise']) {
      stage = 'select-$mode';
      await channel.invokeMethod<Object?>('setNoiseSuppressionEngine', {
        'engine': mode,
      });
      final state = await waitForEngine(channel, mode, previous);
      previous = state['processedFrames'] as int;
      states.add(state);
      final subscriptionDeadline = DateTime.now().add(
        const Duration(seconds: 10),
      );
      while (subscriptions == 0 &&
          DateTime.now().isBefore(subscriptionDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      final before = await inboundPacketReports(receiver);
      await Future<void>.delayed(const Duration(seconds: 4));
      final delta = packetGrowth(before, await inboundPacketReports(receiver));
      deltas.add(delta);
      if (subscriptions != 1 || delta <= 0)
        throw StateError('receiver-audio-missing');
    }
    result['subscriptions'] = subscriptions;
    result['success'] = true;
  } catch (e) {
    result['stage'] = stage;
    result['errorType'] = e.runtimeType.toString();
    try {
      result['failureState'] = await channel.invokeMapMethod<String, dynamic>(
        'getNoiseSuppressionState',
      );
    } catch (_) {}
    result['success'] = false;
  } finally {
    await closeRooms(sender, receiver);
    await listener.dispose();
    await finishOutcome(channel, result);
  }
}
