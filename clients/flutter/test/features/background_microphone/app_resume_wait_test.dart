import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/app_resume_wait.dart';

void main() {
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
