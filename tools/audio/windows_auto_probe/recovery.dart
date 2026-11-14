import 'dart:async';
import 'dart:io';

import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:livekit_client/livekit_client.dart';

import 'livekit_progress.dart';
import 'monitor.dart';

Future<Map<String, Object?>> checkRecovery(
  Room sender,
  Room receiver,
  AudioDeviceController audio,
  NoiseSuppressionMode expected,
) async {
  final mode = Platform.environment['BOOHTA_AUTO_PROBE_RECOVERY'];
  if (mode == null) return {'status': 'NOT_RUN'};
  if (!['signal', 'full', 'muted-full'].contains(mode))
    throw FormatException('recovery-mode');
  final participant = sender.localParticipant!;
  final native = audio.nativeNoise;
  final muted = mode == 'muted-full';
  final listener = sender.createListener(), reconnected = Completer<void>();
  var interruptions = 0;
  listener.on<ReconnectingEvent>((_) {
    interruptions++;
  });
  listener.on<RoomReconnectedEvent>((_) {
    if (!reconnected.isCompleted) reconnected.complete();
  });
  final watch = Stopwatch()..start();
  try {
    if (muted) {
      audio.microphoneMutedIntent = true;
      await participant.setMicrophoneEnabled(false);
    }
    await sender.sendSimulateScenario(
      signalReconnect: mode == 'signal',
      fullReconnect: mode != 'signal',
    );
    await reconnected.future.timeout(const Duration(seconds: 20));
    final elapsed = watch.elapsedMilliseconds;
    if (interruptions == 0 ||
        sender.connectionState != ConnectionState.connected)
      throw StateError('reconnect-not-observed');
    if (muted) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final publications = participant.audioTrackPublications;
      if (participant.isMicrophoneEnabled() ||
          publications.any((p) => p.track?.mediaStreamTrack.enabled == true)) {
        throw StateError('muted-intent-lost');
      }
      audio.microphoneMutedIntent = false;
      await participant.setMicrophoneEnabled(true);
    }
    final progress = await monitorAuto(
      seconds: 6,
      read: () => readAutoSample(native, receiver, expected.name),
    );
    return {
      'scenario': mode,
      'interruptions': interruptions,
      'reconnectedMs': elapsed,
      'mutedIntentChecked': muted,
      ...progress,
    };
  } finally {
    await listener.dispose();
  }
}
