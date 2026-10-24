import 'controller.dart';

extension VoiceRosterRefresh on VoiceRosterController {
  Future<void> refreshVoiceRosters() async {
    final ticket = scope.capture();
    if (disposed || !ticket.isActive || !isReady() || !hasUser() || loading) {
      return;
    }
    loading = true;
    final expected = ++refreshRevision;
    final generation = revision;
    try {
      final rosters = await api.voiceParticipants();
      if (!ticket.isActive ||
          expected != refreshRevision ||
          !isReady() ||
          disposed) {
        return;
      }
      staleTimer?.cancel();
      staleTimer = null;
      voiceRosters = rosters;
      lastUpdatedAt = DateTime.now();
      voiceRosterError = null;
      phase = VoiceRosterPhase.fresh;
    } catch (cause) {
      if (!ticket.isActive ||
          expected != refreshRevision ||
          !isReady() ||
          disposed) {
        return;
      }
      if (cause is ApiFailure && cause.status == 401) {
        expireRosterSession();
      } else if (watching) {
        markLost(generation);
      } else {
        voiceRosters = null;
        phase = VoiceRosterPhase.unavailable;
        voiceRosterError = 'Не удалось обновить состав комнаты.';
      }
    } finally {
      if (ticket.isActive && expected == refreshRevision) {
        loading = false;
        changed();
      }
    }
  }
}
