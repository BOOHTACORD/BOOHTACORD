import 'controller.dart';

extension VoiceRosterStop on VoiceRosterController {
  void stop() {
    watching = false;
    sharedOpen = false;
    sharedGeneration = null;
    sharedRevision = 0;
    sharedTicket = null;
    initialTimer?.cancel();
    initialTimer = null;
    staleTimer?.cancel();
    staleTimer = null;
    revision++;
    voiceRosters = null;
    voiceRosterError = null;
    lastUpdatedAt = null;
    phase = VoiceRosterPhase.initialLoading;
  }
}
