import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';

import 'support.dart';

void main() {
  for (final entry in [(0.0, 24), (1.0, 30)]) {
    test('slow retry jitter ${entry.$1} is bounded', () async {
      final api = RosterApi();
      final scope = SessionScope();
      final timers = <ScheduledRosterTimer>[];
      final owner = VoiceRosterController(
        api,
        scope,
        isReady: () => true,
        hasUser: () => true,
        message: (e) => '$e',
        retryBudget: 0,
        jitter: () => entry.$1,
        schedule: (delay, callback) {
          final timer = ScheduledRosterTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      addTearDown(owner.dispose);
      owner.start();
      api.streams.single.completeError(
        const ApiFailure('unavailable', status: 503),
      );
      await Future<void>.delayed(Duration.zero);
      final retry = owner.retryTimer! as ScheduledRosterTimer;
      expect(retry.delay, Duration(seconds: entry.$2));
      expect(
        timers.where(
          (timer) =>
              timer.isActive && timer.delay != const Duration(seconds: 10),
        ),
        hasLength(1),
      );
      owner.stop();
      expect(retry.isActive, isFalse);
    });
  }
}
