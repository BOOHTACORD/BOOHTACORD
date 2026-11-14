import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../lifecycle/controller.dart';

extension VoiceAdmissionEnable on VoiceController {
  Future<void> enableVoiceMicrophone(
    Room room,
    bool listen,
    SessionTicket ticket,
    int revision,
  ) async {
    if (listen) {
      listenerOnly = true;
      pushToTalkPressed = false;
      microphoneMuted = true;
      microphoneUnavailable = false;
      voicePhase = VoicePhase.listener;
    } else if (audioActivationMode == AudioActivationMode.ptt) {
      microphoneMutedBeforePtt = false;
      pushToTalkPressed = false;
      microphoneMuted = true;
      listenerOnly = false;
      voicePhase = VoicePhase.connected;
    } else {
      try {
        if (!await applyMicrophoneMuted(false)) {
          throw StateError('Микрофон недоступен.');
        }
        if (!active(ticket, revision)) {
          await room.localParticipant?.setMicrophoneEnabled(false);
          return;
        }
        if (room.localParticipant != null) {
          audio.refreshAfterMicrophoneCapture();
        }
        microphoneUnavailable = false;
        listenerOnly = false;
        voicePhase = VoicePhase.connected;
      } catch (_) {
        if (!active(ticket, revision)) return;
        listenerOnly = true;
        microphoneMuted = true;
        microphoneUnavailable = true;
        voicePhase = VoicePhase.listener;
      }
    }
  }
}
