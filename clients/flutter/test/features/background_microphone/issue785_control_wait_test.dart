import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../../test_support/issue785_control_wait.dart';

void main() {
  test(
    'waits for runner resume after notification returns app early',
    () async {
      var reads = 0;

      final result = await waitForControlStatus(
        read: () async {
          reads++;
          return reads == 1
              ? {'status': 'ready'}
              : {'status': 'resume', 'backgroundSecondsObserved': 120};
        },
        expectedStatus: 'resume',
        pendingStatuses: const {'ready'},
        timeout: const Duration(seconds: 1),
        pollInterval: const Duration(milliseconds: 1),
        delay: (_) async {},
      );

      expect(result['status'], 'resume');
      expect(reads, 2);
    },
  );

  test(
    'rejects a terminal control state instead of treating it as pending',
    () async {
      await expectLater(
        waitForControlStatus(
          read: () async => {'status': 'complete'},
          expectedStatus: 'resume',
          pendingStatuses: const {'ready'},
          timeout: const Duration(seconds: 1),
          delay: (_) async {},
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'times out while the runner keeps the command in a pending state',
    () async {
      var now = DateTime.utc(2026, 11, 22);
      await expectLater(
        waitForControlStatus(
          read: () async => {'status': 'ready'},
          expectedStatus: 'resume',
          pendingStatuses: const {'ready'},
          timeout: const Duration(milliseconds: 10),
          pollInterval: const Duration(milliseconds: 5),
          now: () => now,
          delay: (duration) async => now = now.add(duration),
        ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
