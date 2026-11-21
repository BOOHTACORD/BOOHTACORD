import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/system_activity/inactivity_reporter.dart';

void main() {
  test('reports inactivity once per socket and retries a failed send', () {
    final reporter = InactivityReporter();
    final first = Object(), second = Object();
    var sent = 0;
    reporter.report(first, () => throw StateError('socket closed'));
    reporter.report(first, () => sent++);
    reporter.report(first, () => sent++);
    reporter.report(second, () => sent++);
    expect(sent, 2);
  });
}
