import '../../../services/voice_roster_events.dart';
import 'controller.dart';

extension VoiceRosterEvents on VoiceRosterController {
  bool receiveRosterLine(String line, String event, int expected) {
    if (!watching || disposed || expected != revision) return false;
    if (line == 'event: session-expired') {
      expireRosterSession();
      return false;
    }
    if (!line.startsWith('data:')) return true;
    if (event == 'roster-unavailable' || event == 'unavailable') {
      markLost(expected);
      return false;
    }
    try {
      final rooms = parseVoiceRosterEvent(line);
      if (rooms == null) return true;
      refreshRevision++;
      loading = false;
      staleTimer?.cancel();
      staleTimer = null;
      voiceRosters = rooms;
      lastUpdatedAt = DateTime.now();
      voiceRosterError = null;
      retryAttempt = 0;
      phase = VoiceRosterPhase.fresh;
      changed();
      return true;
    } catch (_) {
      markLost(expected);
      return false;
    }
  }
}
