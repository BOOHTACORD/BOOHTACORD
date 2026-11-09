import 'dart:async';
import 'dart:convert';

import 'controller.dart';

extension VoiceRosterWatch on VoiceRosterController {
  void start() {
    if (disposed ||
        !scope.capture().isActive ||
        !hasUser() ||
        !isReady() ||
        watching) {
      return;
    }
    watching = true;
    if (sharedSocket) {
      revision++;
      return;
    }
    unawaited(watch(++revision));
  }

  Future<void> watch(int expected) async {
    final ticket = scope.capture();
    while (ticket.isActive && watching && expected == revision && isReady()) {
      try {
        opening = true;
        final response = await api.voiceRosterEvents();
        if (!ticket.isActive || !watching || disposed || expected != revision) {
          await response.stream.listen(null).cancel();
          return;
        }
        opening = false;
        final done = Completer<void>();
        streamDone = done;
        var event = '';
        subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (!ticket.isActive || expected != revision) return;
                if (line.startsWith('event:')) event = line.substring(6).trim();
                if (line.isEmpty) event = '';
                if (!receiveRosterLine(line, event, expected) &&
                    !done.isCompleted) {
                  done.complete();
                }
              },
              onError: (Object _) {
                if (ticket.isActive) markLost(expected);
                if (!done.isCompleted) done.complete();
              },
              onDone: () {
                if (ticket.isActive) markLost(expected);
                if (!done.isCompleted) done.complete();
              },
            );
        await done.future;
        if (!ticket.isActive || expected != revision) return;
        await subscription?.cancel();
        if (!ticket.isActive || expected != revision) return;
        subscription = null;
        streamDone = null;
      } catch (cause) {
        if (!ticket.isActive || expected != revision) return;
        if (cause is ApiFailure && cause.status == 401) {
          expireRosterSession();
          return;
        }
        opening = false;
        markLost(expected);
        if (cause is ApiFailure && cause.status == 403) {
          voiceRosters = null;
          phase = VoiceRosterPhase.unavailable;
          staleTimer?.cancel();
          staleTimer = null;
          break;
        }
      }
      if (!ticket.isActive || !watching || expected != revision) return;
      if (!await waitForRetry(expected)) break;
    }
    if (ticket.isActive && expected == revision) {
      watching = false;
      opening = false;
      changed();
    }
  }
}
