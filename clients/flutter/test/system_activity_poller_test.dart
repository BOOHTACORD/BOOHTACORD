import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/system_activity/poller.dart';

void main() {
  testWidgets('reports only recent confirmed input and stops cleanly', (
    tester,
  ) async {
    Duration? idle;
    bool? locked = false;
    var reports = 0;
    var inactive = 0;
    final poller = SystemActivityPoller(
      readIdle: () => idle,
      readLocked: () => locked,
      report: () => reports++,
      reportInactive: () => inactive++,
    );
    poller.start();
    await tester.pump(const Duration(seconds: 10));
    expect(reports, 0);
    idle = const Duration(seconds: 4);
    await tester.pump(const Duration(seconds: 10));
    expect(reports, 1);
    idle = const Duration(minutes: 6);
    await tester.pump(const Duration(seconds: 30));
    expect(reports, 1);
    expect(inactive, 3);
    idle = null; // Unknown, locked, or unavailable must not assert activity.
    await tester.pump(const Duration(seconds: 10));
    expect(reports, 1);
    locked = true;
    await tester.pump(const Duration(seconds: 10));
    expect(inactive, 4);
    locked = false;
    idle = const Duration(seconds: 2);
    await tester.pump(const Duration(seconds: 10));
    expect(reports, 2);
    poller.stop();
    await tester.pump(const Duration(seconds: 30));
    expect(reports, 2);
  });

  testWidgets('duplicate starts do not create duplicate timers', (
    tester,
  ) async {
    var reports = 0;
    final poller = SystemActivityPoller(
      readIdle: () => Duration.zero,
      readLocked: () => false,
      report: () => reports++,
      reportInactive: () {},
    );
    poller.start();
    poller.start();
    await tester.pump(const Duration(seconds: 10));
    expect(reports, 1);
    poller.stop();
  });
}
