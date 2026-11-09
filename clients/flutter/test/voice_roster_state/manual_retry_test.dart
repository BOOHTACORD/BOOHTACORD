import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test(
    'manual retry cancels the slow timer and opens only one stream',
    () async {
      final h = RosterHarness();
      addTearDown(h.owner.dispose);
      h.owner.start();
      for (var i = 0; i < 3; i++) {
        h.api.streams.last.completeError(
          const ApiFailure('unavailable', status: 503),
        );
        await h.flush();
        if (i < 2) {
          (h.owner.retryTimer! as ScheduledRosterTimer).fire();
          await h.flush();
        }
      }
      final slow = h.owner.retryTimer! as ScheduledRosterTimer;
      expect(slow.delay, const Duration(seconds: 30));
      h.owner.retryVoiceRosters();
      h.owner.retryVoiceRosters();
      expect(slow.isActive, isFalse);
      expect(h.api.streams, hasLength(4));
      slow.fire();
      await h.flush();
      expect(h.api.streams, hasLength(4));
      h.owner.stop();
      h.api.streams.last.completeError(const ApiFailure('closed'));
      await h.flush();
    },
  );
}
