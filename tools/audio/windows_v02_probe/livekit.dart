import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

import '../windows_livekit_probe/metrics.dart';
import '../../qa/windows_v02_probe/packet_delta.dart';
import 'reports.dart';
import 'support.dart';

const channel = MethodChannel('FlutterWebRTC.Method');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Text('Audio probe'))));
  final result = <String, Object?>{};
  final sender = lk.Room(), receiver = lk.Room();
  var stage = 'start', subscriptions = 0;
  final reconnected = Completer<void>();
  final resubscribed = Completer<void>();
  final listener = receiver.createListener();
  final senderListener = sender.createListener();
  senderListener.on<lk.RoomReconnectedEvent>((_) {
    if (!reconnected.isCompleted) reconnected.complete();
  });
  listener.on<lk.TrackSubscribedEvent>((event) {
    if (event.track is lk.RemoteAudioTrack) {
      subscriptions++;
      if (subscriptions > 1 && !resubscribed.isCompleted)
        resubscribed.complete();
      unawaited(rtc.Helper.setVolume(0, event.track.mediaStreamTrack));
    }
  });
  try {
    await requireResearchMarker();
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
    stage = 'engine-select';
    await channel.invokeMethod<Object?>('setNoiseSuppressionEngine', {
      'engine': 'rnnoise',
    });
    stage = 'microphone-publish';
    final pub = await sender.localParticipant!.setMicrophoneEnabled(
      true,
      audioCaptureOptions: const lk.AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: false,
      ),
    );
    stage = 'media';
    await Future<void>.delayed(const Duration(seconds: 10));
    result['published'] = pub != null;
    result['subscribed'] = subscriptions > 0;
    result.addAll(await inboundCounters(receiver));
    final state = await channel.invokeMapMethod<String, dynamic>(
      'getNoiseSuppressionState',
    );
    result['capture'] = state;
    final firstPassed =
        pub != null &&
        subscriptions > 0 &&
        (result['receivedPackets'] as int) > 0 &&
        state?['effectiveEngine'] == 'rnnoise' &&
        (state?['processedFrames'] as int? ?? 0) > 0 &&
        (state?['fallbackFrames'] as int? ?? 0) == 0;
    if (!firstPassed) throw StateError('initial-media-failed');
    final before = subscriptions;
    stage = 'full-reconnect';
    await sender.sendSimulateScenario(fullReconnect: true);
    await reconnected.future.timeout(const Duration(seconds: 35));
    await resubscribed.future.timeout(const Duration(seconds: 15));
    await Future<void>.delayed(const Duration(seconds: 1));
    final baseline = await inboundPacketReports(receiver);
    await Future<void>.delayed(const Duration(seconds: 8));
    final after = await channel.invokeMapMethod<String, dynamic>(
      'getNoiseSuppressionState',
    );
    final received = await inboundCounters(receiver);
    final later = await inboundPacketReports(receiver);
    result['reconnected'] = true;
    result['resubscribed'] = subscriptions > before;
    result['afterReconnect'] = after;
    result['receivedPacketsAfter'] = received['receivedPackets'];
    final packetDelta = packetGrowth(baseline, later);
    result['packetDeltaAfter'] = packetDelta;
    result['success'] =
        subscriptions > before &&
        packetDelta > 0 &&
        after?['effectiveEngine'] == 'rnnoise' &&
        (after?['processedFrames'] as int? ?? 0) > 0 &&
        (after?['fallbackFrames'] as int? ?? 0) == 0;
  } catch (e) {
    result['stage'] = stage;
    result['errorType'] = e.runtimeType.toString();
    result['success'] = false;
  } finally {
    await closeRooms(sender, receiver);
    await listener.dispose();
    await senderListener.dispose();
    await finishOutcome(channel, result);
  }
}
