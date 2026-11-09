import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test(
    'transient outage keeps one slow retry and recovers after budget',
    () async {
      final h = RosterHarness();
      addTearDown(h.owner.dispose);
      h.owner.start();
      for (var attempt = 0; attempt < 5; attempt++) {
        h.api.streams.last.completeError(
          const ApiFailure('unavailable', status: 503),
        );
        await h.flush();
        expect(h.owner.watching, isTrue);
        expect(h.owner.canRetry, isTrue);
        final retry = h.owner.retryTimer! as ScheduledRosterTimer;
        expect(
          retry.delay,
          attempt < 2
              ? Duration(seconds: 2 * (1 << attempt))
              : const Duration(seconds: 30),
        );
        expect(
          h.timers.where(
            (t) => t.isActive && t.delay != const Duration(seconds: 10),
          ),
          hasLength(1),
        );
        retry.fire();
        await h.flush();
      }
      expect(h.api.streams, hasLength(6));
      final stream = await h.connect();
      h.snapshot(stream);
      await h.flush();
      expect(h.owner.phase, VoiceRosterPhase.fresh);
      expect(h.owner.retryAttempt, 0);
      await stream.close();
      await h.flush();
      expect(
        (h.owner.retryTimer! as ScheduledRosterTimer).delay,
        const Duration(seconds: 2),
      );
      h.owner.stop();
      expect(h.timers.where((t) => t.isActive), isEmpty);
    },
  );
  test(
    '401 expires without retries; 403 clears roster and stops retries',
    () async {
      for (final status in [401, 403]) {
        final h = RosterHarness();
        var expired = false;
        h.api.onUnauthorized = () => expired = true;
        h.owner.start();
        h.api.streams.single.completeError(
          ApiFailure('denied', status: status),
        );
        await h.flush();
        expect(h.owner.voiceRosters, isNull);
        expect(h.owner.watching, isFalse);
        expect(expired, status == 401);
        expect(
          h.owner.phase,
          status == 401
              ? VoiceRosterPhase.sessionExpired
              : VoiceRosterPhase.unavailable,
        );
        expect(h.owner.retryTimer, isNull);
        h.owner.dispose();
      }
    },
  );
  test(
    'logout clears data and cancels all timers and stream callbacks',
    () async {
      final h = RosterHarness();
      h.owner.start();
      final stream = await h.connect();
      h.snapshot(stream);
      await h.flush();
      h.scope.close();
      h.owner.stop();
      h.snapshot(stream);
      await h.flush();
      expect(h.owner.voiceRosters, isNull);
      expect(h.owner.voiceRosterError, isNull);
      expect(h.timers.where((t) => t.isActive), isEmpty);
      h.owner.dispose();
      await stream.close();
    },
  );
}
