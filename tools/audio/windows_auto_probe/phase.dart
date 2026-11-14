import 'dart:async';

import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../windows_client_probe/loopback.dart';
import 'capabilities.dart';

Future<Map<String, Object?>> runAutoPhase(bool deepfilter) async {
  final native = NativeNoiseSuppression(
    allowExperimentalDeepFilter: deepfilter,
  );
  final loopback = LocalAudioLoopback(mutePlayback: true);
  MediaStream? stream;
  try {
    final selected = await native.prepare(NoiseSuppressionMode.auto);
    final expected = deepfilter
        ? NoiseSuppressionMode.deepfilter
        : NoiseSuppressionMode.rnnoise;
    final capabilities = await probeCapabilities();
    if (selected != expected) {
      return {
        'success': false,
        'selected': selected.name,
        'expected': expected.name,
        'capabilities': capabilities,
        'failureReason': native.state.failureReason,
      };
    }
    stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': false,
        'autoGainControl': false,
      },
      'video': false,
    });
    if (stream.getAudioTracks().length != 1)
      throw StateError('audio-track-count');
    await loopback.connect(stream);
    await Future<void>.delayed(const Duration(seconds: 6));
    await native.refresh();
    final state = native.state;
    final counters = await loopback.counters();
    return {
      'selected': selected.name,
      'capabilities': capabilities,
      'requested': state.requestedMode.name,
      'effective': state.effectiveMode,
      'status': state.status,
      'processedFrames': state.processedFrames,
      'fallbackFrames': state.fallbackFrames,
      'sampleRate': state.sampleRate,
      'channels': state.channels,
      'trackEnabled': stream.getAudioTracks().single.enabled,
      'senderState': (await loopback.sender!.getConnectionState())?.name,
      'receiverState': (await loopback.receiver!.getConnectionState())?.name,
      'senderIce': loopback.sender!.iceConnectionState?.name,
      'receiverIce': loopback.receiver!.iceConnectionState?.name,
      ...counters,
      'remoteAudioTrack': loopback.receivedTrack,
      'success':
          loopback.receivedTrack &&
          counters['receivedPackets']! > 0 &&
          state.requestedMode == NoiseSuppressionMode.auto &&
          state.effectiveMode == expected.name &&
          state.status == 'active' &&
          state.processedFrames > 0 &&
          state.fallbackFrames == 0,
    };
  } finally {
    try {
      await loopback.close();
    } catch (_) {}
    for (final track in stream?.getTracks() ?? <MediaStreamTrack>[]) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await stream?.dispose();
    } catch (_) {}
    try {
      await native.prepare(NoiseSuppressionMode.browser);
    } catch (_) {}
    native.dispose();
  }
}
