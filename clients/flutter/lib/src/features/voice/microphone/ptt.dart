import '../lifecycle/controller.dart';

extension VoiceMicrophonePtt on VoiceController {
  Future<void> setPushToTalkPressed(bool pressed) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision) || !microphoneAllowed) return;
    if (audioActivationMode != AudioActivationMode.ptt ||
        pushToTalkPressed == pressed) {
      return;
    }
    if (pressed &&
        voicePhase != VoicePhase.connected &&
        voicePhase != VoicePhase.listener) {
      return;
    }
    pushToTalkPressed = pressed;
    audioActivationError = null;
    if (voicePhase == VoicePhase.reconnecting) {
      microphoneMuted = true;
      notifyListeners();
      return;
    }
    if (room == null) {
      notifyListeners();
      return;
    }
    final shouldMute = !pressed || deafened;
    final success = await applyMicrophoneMuted(shouldMute);
    if (!active(ticket, revision) || pushToTalkPressed != pressed) return;
    if (!success) {
      pushToTalkPressed = false;
      await applyMicrophoneMuted(true);
    } else if (pressed && !shouldMute) {
      listenerOnly = false;
      if (voicePhase == VoicePhase.listener) voicePhase = VoicePhase.connected;
    }
    notifyListeners();
  }
}
