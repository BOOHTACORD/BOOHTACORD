import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../services/audio_preferences.dart';
import '../../audio/devices/model_preflight.dart';
import '../lifecycle/controller.dart';
import '../background_microphone/admission.dart';

part 'toggle.dart';

extension VoiceMicrophoneCapture on VoiceController {
  Future<bool> applyMicrophoneMuted(bool muted) {
    final ticket = scope.capture();
    final revision = operationRevision;
    final request = ++microphoneRevision;
    final targetRoom = room;
    final participant = targetRoom?.localParticipant;
    bool current() => active(ticket, revision) && identical(room, targetRoom);
    audio.microphoneMutedIntent = muted;
    audio.microphoneVad = audioActivationMode == AudioActivationMode.vad;
    if (muted) {
      audio.nativeMicrophone.pause();
      final track = participant
          ?.getTrackPublicationBySource(TrackSource.microphone)
          ?.track;
      if (track is LocalAudioTrack) unawaited(track.mute(stopOnMute: false));
      unawaited(audio.nativeNoise.reset());
    }
    final operation = audio.nativeNoise.run(() async {
      if (!current()) return false;
      try {
        if (!muted) {
          await preflightBackgroundMicrophone();
          await audio.prepareNoiseForCapture();
          await audio.applyMicrophoneControls();
        }
        if (!current()) return false;
        await audio.nativeNoise.reset();
        if (!muted &&
            !await audio.prepareNoiseModelForCaptureIfNeeded(
              () =>
                  current() &&
                  request == microphoneRevision &&
                  !audio.microphoneMutedIntent,
            )) {
          return false;
        }
        await participant?.setMicrophoneEnabled(
          !audio.microphoneMutedIntent,
          audioCaptureOptions: audio.captureOptions,
        );
        if (current()) await promoteBackgroundMicrophone(participant);
        if (!current()) {
          await microphoneForeground.stop();
          if (!muted) {
            try {
              await participant?.setMicrophoneEnabled(false);
            } catch (_) {}
          }
          return false;
        }
        if (!muted) {
          if (audio.captureNoiseOverride == NoiseSuppressionMode.browser &&
              (audio.audioProcessing.noiseSuppressionMode ==
                      NoiseSuppressionMode.rnnoise ||
                  audio.audioProcessing.noiseSuppressionMode ==
                      NoiseSuppressionMode.deepfilter)) {
            audio.nativeNoise.confirmFallback(
              audio.nativeNoise.state.failureReason ?? 'unsupported',
              unsupported:
                  audio.audioProcessing.noiseSuppressionMode ==
                      NoiseSuppressionMode.rnnoise ||
                  audio.nativeNoise.state.failureReason ==
                      'processor-unavailable' ||
                  audio.nativeNoise.state.failureReason == 'unsupported',
            );
          }
          audio.monitorNativeNoise();
          audio.nativeMicrophone.monitor();
        }
        if (request == microphoneRevision) {
          microphoneMuted = muted;
          if (!muted) {
            audio.refreshAfterMicrophoneCapture();
            microphoneUnavailable = false;
          }
        }
        return true;
      } catch (cause) {
        await microphoneForeground.stop();
        if (current() && request == microphoneRevision) {
          microphoneMuted = true;
          if (!muted) microphoneUnavailable = true;
          audioActivationError =
              'Не удалось изменить микрофон: ${formatError(cause)}';
        }
        return false;
      }
    });
    microphoneTail = operation.then((_) {});
    return operation;
  }
}
