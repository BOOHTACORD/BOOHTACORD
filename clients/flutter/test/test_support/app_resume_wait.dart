import 'dart:async';

import 'package:flutter/widgets.dart';

Future<void> waitForAppBackgroundThenResume({
  required AppLifecycleState? Function() readLifecycleState,
  required Duration timeout,
  Duration pollInterval = const Duration(milliseconds: 100),
  Future<void> Function(Duration duration)? delay,
}) async {
  if (timeout < Duration.zero) {
    throw ArgumentError.value(timeout, 'timeout', 'must not be negative');
  }
  if (pollInterval <= Duration.zero) {
    throw ArgumentError.value(
      pollInterval,
      'pollInterval',
      'must be greater than zero',
    );
  }

  final wait = delay ?? Future<void>.delayed;
  final elapsed = Stopwatch()..start();
  while (readLifecycleState() == AppLifecycleState.resumed) {
    final remaining = timeout - elapsed.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException(
        'The app did not enter the background before the deadline.',
        timeout,
      );
    }
    await wait(remaining < pollInterval ? remaining : pollInterval);
  }

  final remaining = timeout - elapsed.elapsed;
  await waitForAppResume(
    readLifecycleState: readLifecycleState,
    timeout: remaining < Duration.zero ? Duration.zero : remaining,
    pollInterval: pollInterval,
    delay: wait,
  );
}

Future<void> waitForAppResume({
  required AppLifecycleState? Function() readLifecycleState,
  required Duration timeout,
  Duration pollInterval = const Duration(milliseconds: 100),
  Future<void> Function(Duration duration)? delay,
}) async {
  if (timeout < Duration.zero) {
    throw ArgumentError.value(timeout, 'timeout', 'must not be negative');
  }
  if (pollInterval <= Duration.zero) {
    throw ArgumentError.value(
      pollInterval,
      'pollInterval',
      'must be greater than zero',
    );
  }

  final wait = delay ?? Future<void>.delayed;
  final elapsed = Stopwatch()..start();
  while (readLifecycleState() != AppLifecycleState.resumed) {
    final remaining = timeout - elapsed.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException(
        'The app did not resume before the deadline.',
        timeout,
      );
    }
    await wait(remaining < pollInterval ? remaining : pollInterval);
  }
}
