import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/system_activity/capabilities.dart';

void main() {
  test('only Windows advertises confirmed system activity', () {
    expect(
      activityCapabilities('existing', isWindows: true),
      'existing,confirmed_activity_v1',
    );
    expect(activityCapabilities('existing', isWindows: false), 'existing');
    expect(
      activityCapabilities('existing', isWindows: true, initialIdle: true),
      'existing,confirmed_activity_v1,initial_idle_v1',
    );
    expect(
      activityCapabilities('existing', isWindows: false, initialIdle: true),
      'existing',
    );
  });

  test('initial idle is advertised only for a reliable five-minute sample', () {
    expect(
      initialIdleCapability(locked: false, idle: const Duration(minutes: 5)),
      isTrue,
    );
    expect(
      initialIdleCapability(locked: true, idle: const Duration(minutes: 6)),
      isTrue,
    );
    expect(
      initialIdleCapability(locked: null, idle: const Duration(minutes: 6)),
      isFalse,
    );
    expect(
      initialIdleCapability(locked: false, idle: const Duration(seconds: 299)),
      isFalse,
    );
    expect(initialIdleCapability(locked: true, idle: null), isFalse);
  });
}
