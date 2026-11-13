part of 'capture.dart';

extension VoiceMicrophoneToggle on VoiceController {
  Future<void> toggleMicrophone() async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision) ||
        room == null ||
        deafened ||
        audioActivationMode == AudioActivationMode.ptt) {
      return;
    }
    final muted = !microphoneMuted;
    microphoneMuted = muted;
    final success = await applyMicrophoneMuted(muted);
    if (!active(ticket, revision)) return;
    if (!success) {
      microphoneMuted = true;
      microphoneUnavailable = true;
      error = audioActivationError;
    } else if (!muted) {
      error = null;
      listenerOnly = false;
      if (voicePhase == VoicePhase.listener) voicePhase = VoicePhase.connected;
    }
    notifyListeners();
  }
}
