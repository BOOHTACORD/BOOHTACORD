import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../screen/lifecycle/controller.dart';
import '../lifecycle/controller.dart';

extension VoiceAdmissionFinalize on VoiceController {
  Future<void> finalizeVoiceAdmission({
    required Room? candidate,
    required EventsListener<RoomEvent>? events,
    required String? lease,
    required bool connected,
    required SessionTicket ticket,
    required int revision,
  }) async {
    if (!connected) {
      await screen.stopScreenShare();
      try {
        await candidate?.disconnect();
      } catch (_) {}
      await events?.dispose();
      if (identical(voiceEvents, events)) voiceEvents = null;
      if (lease != null && ticket.isActive) {
        if (voiceRecoveryActive) {
          voiceRecoveryReleasedLeases.add(lease);
          if (voiceRecoveryReleasedLeases.length > 16) {
            voiceRecoveryReleasedLeases.remove(voiceRecoveryReleasedLeases.first);
          }
        }
        try {
          await api.releaseVoice(lease);
        } catch (_) {}
      }
    }
    if (identical(pendingRoom, candidate)) pendingRoom = null;
    if (active(ticket, revision)) {
      voiceAdmissionPending = false;
      notifyListeners();
    }
  }
}
