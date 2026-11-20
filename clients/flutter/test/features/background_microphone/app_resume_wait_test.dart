import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/app_resume_wait.dart';

void main() {
  test('waits for a background transition before accepting resume', () async {
    var state = AppLifecycleState.resumed;
    var polls = 0;

    await waitForAppBackgroundThenResume(
      readLifecycleState: () => state,
      timeout: const Duration(seconds: 1),
      pollInterval: const Duration(milliseconds: 10),
      delay: (_) async {
        polls++;
        if (polls == 2) state = AppLifecycleState.paused;
        if (polls == 4) state = AppLifecycleState.resumed;
      },
    );

    expect(polls, 4);
  });

  test('times out when the app never leaves resumed', () async {
    await expectLater(
      waitForAppBackgroundThenResume(
        readLifecycleState: () => AppLifecycleState.resumed,
        timeout: Duration.zero,
        delay: (_) async {},
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('waits until the app returns to resumed before continuing', () async {
    var state = AppLifecycleState.paused;
    var polls = 0;

    await waitForAppResume(
      readLifecycleState: () => state,
      timeout: const Duration(seconds: 1),
      pollInterval: const Duration(milliseconds: 10),
      delay: (_) async {
        polls++;
        if (polls == 3) state = AppLifecycleState.resumed;
      },
    );

    expect(polls, 3);
  });

  test('fails with a bounded timeout when the app never resumes', () async {
    await expectLater(
      waitForAppResume(
        readLifecycleState: () => AppLifecycleState.paused,
        timeout: Duration.zero,
        delay: (_) async {},
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
