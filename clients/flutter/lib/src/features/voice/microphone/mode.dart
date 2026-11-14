import '../lifecycle/controller.dart';

extension VoiceMicrophoneMode on VoiceController {
  Future<void> setAudioActivationMode(AudioActivationMode next) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    if (audioActivationMode == next) return;
    final previous = audioActivationMode;
    audio.microphoneVad = next == AudioActivationMode.vad;
    if (next == AudioActivationMode.ptt) {
      microphoneMutedBeforePtt = microphoneMuted;
      audioActivationMode = next;
      pushToTalkPressed = false;
      if (pushToTalkKeyId == null && !usesTouchPushToTalk) {
        audioActivationError = 'Назначьте клавишу для push-to-talk.';
      } else {
        audioActivationError = null;
      }
      if (room != null && voicePhase != VoicePhase.leaving) {
        await applyMicrophoneMuted(true);
        if (!active(ticket, revision)) return;
      }
    } else {
      pushToTalkPressed = false;
      audioActivationMode = next;
      audioActivationError = null;
      if (room != null && voicePhase != VoicePhase.leaving) {
        await applyMicrophoneMuted(
          !microphoneAllowed || deafened ? true : microphoneMutedBeforePtt,
        );
        if (!active(ticket, revision)) return;
      }
    }
    if (!active(ticket, revision)) return;
    try {
      await audioPreferences?.setActivationMode(
        next == AudioActivationMode.ptt ? 'PTT' : 'VAD',
      );
      if (!active(ticket, revision)) return;
    } catch (cause) {
      if (!active(ticket, revision)) return;
      audioActivationMode = previous;
      audio.microphoneVad = previous == AudioActivationMode.vad;
      audioActivationError =
          'Не удалось сохранить режим микрофона: ${cause.runtimeType}.';
      if (room != null) {
        await applyMicrophoneMuted(
          previous == AudioActivationMode.ptt
              ? !microphoneAllowed || !pushToTalkPressed || deafened
              : !microphoneAllowed || deafened || microphoneMutedBeforePtt,
        );
        if (!active(ticket, revision)) return;
      }
    }
    if (active(ticket, revision)) notifyListeners();
  }
}
