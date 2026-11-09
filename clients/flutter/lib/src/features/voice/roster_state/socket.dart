import '../../../models.dart';
import '../../realtime/lifecycle/event.dart';
import '../../realtime/lifecycle/roster_payload.dart';
import 'controller.dart';

extension VoiceRosterSharedSocket on VoiceRosterController {
  void sharedSocketStart() {
    if (!watching || disposed || !scope.capture().isActive) {
      return;
    }
    final ticket = scope.capture();
    sharedOpen = true;
    sharedTicket = ticket;
    sharedGeneration = null;
    sharedRevision = 0;
    initialTimer?.cancel();
    final expected = revision;
    initialTimer = schedule(staleTimeout, () {
      initialTimer = null;
      if (sharedOpen && ticket.isActive && identical(sharedTicket, ticket)) {
        markLost(expected);
      }
    });
  }

  void sharedSocketEnd() {
    if (!sharedOpen) return;
    sharedOpen = false;
    sharedTicket = null;
    initialTimer?.cancel();
    initialTimer = null;
    markLost(revision);
  }

  bool acceptSocketEvent(RealtimeEvent event) {
    if (!isRosterKind(event.kind)) return false;
    if (!sharedOpen ||
        !watching ||
        disposed ||
        sharedTicket?.isActive != true ||
        !isReady() ||
        !hasUser()) {
      return true;
    }
    initialTimer?.cancel();
    initialTimer = null;
    if (!validRosterPayload(event.kind, event.payload) ||
        event.kind == 'voice.roster.unavailable') {
      markLost(revision);
      return true;
    }
    final generation = event.payload['generation'] as String;
    final nextRevision = (event.payload['revision'] as num).toInt();
    if (sharedGeneration == generation &&
        (nextRevision < sharedRevision ||
            (nextRevision == sharedRevision &&
                phase != VoiceRosterPhase.stale &&
                phase != VoiceRosterPhase.unavailable))) {
      return true;
    }
    try {
      final rooms = (event.payload['channels'] as List)
          .map((item) => VoiceRoomRoster.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
      sharedGeneration = generation;
      sharedRevision = nextRevision;
      staleTimer?.cancel();
      staleTimer = null;
      voiceRosters = rooms;
      lastUpdatedAt = DateTime.now();
      voiceRosterError = null;
      phase = VoiceRosterPhase.fresh;
      changed();
    } catch (_) {
      markLost(revision);
    }
    return true;
  }
}
