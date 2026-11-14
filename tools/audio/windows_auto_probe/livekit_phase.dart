import 'dart:async';
import 'dart:io';

import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

import '../windows_livekit_probe/metrics.dart';
import 'capabilities.dart';

Future<Map<String, Object?>> runAutoLivekitPhase(bool deepfilter) async {
  final native = NativeNoiseSuppression(
    allowExperimentalDeepFilter: deepfilter,
  );
  final sender = lk.Room(), receiver = lk.Room();
  final listener = receiver.createListener();
  final muted = Completer<void>();
  final result = <String, Object?>{};
  var stage = 'receiver-connect';
  listener.on<lk.TrackSubscribedEvent>((event) async {
    if (event.track is! lk.RemoteAudioTrack || muted.isCompleted) return;
    try {
      await rtc.Helper.setVolume(0, event.track.mediaStreamTrack);
      muted.complete();
    } catch (error) {
      muted.completeError(error);
    }
  });
  try {
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
    stage = 'auto-prepare';
    final selected = await native.prepare(NoiseSuppressionMode.auto);
    final baseline = native.state;
    final expected = deepfilter
        ? NoiseSuppressionMode.deepfilter
        : NoiseSuppressionMode.rnnoise;
    result['selected'] = selected.name;
    result['capabilities'] = await probeCapabilities();
    if (selected != expected) throw StateError('unexpected-auto-engine');
    stage = 'capture';
    final published = await sender.localParticipant!.setMicrophoneEnabled(
      true,
      audioCaptureOptions: const lk.AudioCaptureOptions(
        echoCancellation: true,
        autoGainControl: false,
        noiseSuppression: false,
      ),
    );
    await muted.future.timeout(const Duration(seconds: 15));
    stage = 'media';
    await Future<void>.delayed(const Duration(seconds: 6));
    await native.refresh();
    final state = native.state;
    final counters = await inboundCounters(receiver);
    result.addAll({
      'requested': state.requestedMode.name,
      'effective': state.effectiveMode,
      'status': state.status,
      'processedDelta': state.processedFrames - baseline.processedFrames,
      'fallbackDelta': state.fallbackFrames - baseline.fallbackFrames,
      'sampleRate': state.sampleRate,
      'channels': state.channels,
      ...counters,
      'published': published != null,
      'receiverPlaybackMuted': muted.isCompleted,
      'success':
          published != null &&
          counters['receivedPackets']! > 0 &&
          state.requestedMode == NoiseSuppressionMode.auto &&
          state.effectiveMode == expected.name &&
          state.status == 'active' &&
          state.processedFrames > baseline.processedFrames &&
          state.fallbackFrames == baseline.fallbackFrames,
    });
  } catch (error) {
    result.addAll({
      'success': false,
      'stage': stage,
      'errorType': error.runtimeType.toString(),
    });
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
      await native.prepare(NoiseSuppressionMode.browser);
    } catch (_) {}
    native.dispose();
  }
  return result;
}
