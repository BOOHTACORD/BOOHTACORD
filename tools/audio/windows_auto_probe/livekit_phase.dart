import 'dart:async';
import 'dart:io';

import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

import 'capabilities.dart';
import 'monitor.dart';
import 'livekit_progress.dart';
import 'receiver_mute.dart';
import 'recovery.dart';
import 'failure_latch.dart';

Future<Map<String, Object?>> runAutoLivekitPhase(
  bool deepfilter, {
  int seconds = 6,
}) async {
  final sender = lk.Room(), receiver = lk.Room();
  final audio = AudioDeviceController(readRoom: () => sender)
    ..audioProcessing = const AudioProcessingPreferences(
      noiseSuppressionMode: NoiseSuppressionMode.auto,
      echoCancellation: true,
      autoGainControl: false,
    )
    ..microphoneMutedIntent = false;
  final native = audio.nativeNoise;
  final failure = FailureLatch();
  native.addListener(() => failure.observe(native.state.failureReason));
  final listener = receiver.createListener();
  final playback = ReceiverMute<rtc.MediaStreamTrack>(
    (track) => rtc.Helper.setVolume(0, track),
  );
  final result = <String, Object?>{};
  var stage = 'receiver-connect';
  listener.on<lk.TrackSubscribedEvent>((event) async {
    if (event.track is lk.RemoteAudioTrack)
      await playback.apply(event.track.mediaStreamTrack);
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
    final selected =
        (await audio.prepareNoiseForCapture()).noiseSuppressionMode;
    final expected = deepfilter
        ? NoiseSuppressionMode.deepfilter
        : NoiseSuppressionMode.rnnoise;
    result['selected'] = selected.name;
    result['capabilities'] = await probeCapabilities();
    if (selected != expected) throw StateError('unexpected-auto-engine');
    stage = 'capture';
    final published = await sender.localParticipant!.setMicrophoneEnabled(
      true,
      audioCaptureOptions: audio.captureOptions,
    );
    await playback.ready.future.timeout(const Duration(seconds: 15));
    audio.monitorNativeNoise();
    stage = 'recovery';
    final recovery = await checkRecovery(sender, receiver, audio, expected);
    result['recovery'] = recovery;
    if (recovery['success'] == false) throw StateError('recovery-media-failed');
    stage = 'media';
    final progress = await monitorAuto(
      seconds: seconds,
      read: () => readAutoSample(native, receiver, expected.name),
    );
    final observation = await readAutoObservation(
      native,
      receiver,
      failure.reason,
    );
    result.addAll({
      ...observation,
      ...progress,
      'published': published != null,
      'receiverPlaybackMuted': playback.ready.isCompleted && !playback.failed,
      'success':
          published != null &&
          !playback.failed &&
          (observation['receivedPackets'] as int) > 0 &&
          progress['success'] == true,
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
    audio.dispose();
  }
  return result;
}
