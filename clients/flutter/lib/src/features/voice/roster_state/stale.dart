import 'controller.dart';

extension VoiceRosterStale on VoiceRosterController {
  void markLost(int expected) {
    if (!watching || disposed || expected != revision) return;
    voiceRosterError = 'Не удалось обновить состав комнаты.';
    phase = voiceRosters == null
        ? VoiceRosterPhase.unavailable
        : VoiceRosterPhase.stale;
    changed();
    final ticket = scope.capture();
    staleTimer ??= schedule(staleTimeout, () {
      staleTimer = null;
      if (!ticket.isActive || disposed || expected != revision) return;
      voiceRosters = null;
      phase = VoiceRosterPhase.unavailable;
      changed();
    });
  }
}
