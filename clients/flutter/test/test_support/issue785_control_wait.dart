import 'dart:async';

typedef Issue785ControlReader = Future<Map<String, Object?>?> Function();
typedef Issue785ControlDelay = Future<void> Function(Duration duration);

Future<Map<String, Object?>> waitForControlStatus({
  required Issue785ControlReader read,
  required String expectedStatus,
  required Set<String> pendingStatuses,
  required Duration timeout,
  Duration pollInterval = const Duration(milliseconds: 250),
  Issue785ControlDelay? delay,
  DateTime Function()? now,
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

  final readClock = now ?? DateTime.now;
  final wait = delay ?? Future<void>.delayed;
  final started = readClock();
  while (true) {
    final control = await read();
    if (control != null) {
      final status = control['status'];
      if (status == expectedStatus) return control;
      if (status is! String || !pendingStatuses.contains(status)) {
        throw StateError(
          'Unexpected Issue 785 control status while waiting for '
          '$expectedStatus: $status',
        );
      }
    }

    final elapsed = readClock().difference(started);
    final remaining = timeout - elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException(
        'Timed out waiting for Issue 785 control status $expectedStatus',
        timeout,
      );
    }
    await wait(remaining < pollInterval ? remaining : pollInterval);
  }
}
