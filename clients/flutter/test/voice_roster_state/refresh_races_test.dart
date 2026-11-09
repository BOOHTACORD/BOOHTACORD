import 'dart:async';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test('GET refresh does not invalidate SSE and old GET cannot overwrite newer pushed snapshot', () async {
    final h = RosterHarness();
    addTearDown(h.owner.dispose);
    h.owner.start();
    final stream = await h.connect();
    final generation = h.owner.revision;
    h.api.snapshotResponse = Completer<List<VoiceRoomRoster>>();
    final refreshing = h.owner.refreshVoiceRosters();
    expect(h.owner.revision, generation);
    h.snapshot(stream);
    await h.flush();
    h.api.snapshotResponse!.complete([]);
    await refreshing;
    expect(h.owner.phase, VoiceRosterPhase.fresh);
    expect(h.owner.voiceRosters, hasLength(1));
    expect(h.owner.loading, isFalse);
    h.owner.stop();
    await stream.close();
  });
  test(
    '401 refresh clears a loaded snapshot without fabricating fresh empty',
    () async {
      final h = RosterHarness();
      addTearDown(h.owner.dispose);
      h.owner.start();
      final stream = await h.connect();
      h.snapshot(stream);
      await h.flush();
      h.api.snapshotResponse = Completer<List<VoiceRoomRoster>>();
      final refreshing = h.owner.refreshVoiceRosters();
      h.api.snapshotResponse!.completeError(
        const ApiFailure('expired', status: 401),
      );
      await refreshing;
      expect(h.owner.voiceRosters, isNull);
      expect(h.owner.phase, VoiceRosterPhase.sessionExpired);
      await stream.close();
    },
  );
  test('stale retention expires while slow retry remains scheduled', () async {
    final h = RosterHarness();
    addTearDown(h.owner.dispose);
    h.owner.start();
    final stream = await h.connect();
    h.snapshot(stream);
    await h.flush();
    h.owner.retryAttempt = h.owner.retryBudget;
    await stream.close();
    await h.flush();
    expect(h.owner.watching, isTrue);
    expect(h.owner.retryTimer, isNotNull);
    expect(h.owner.phase, VoiceRosterPhase.stale);
    h.timers
        .singleWhere((timer) => timer.delay == const Duration(seconds: 10))
        .fire();
    expect(h.owner.voiceRosters, isNull);
    expect(h.owner.phase, VoiceRosterPhase.unavailable);
  });
}
