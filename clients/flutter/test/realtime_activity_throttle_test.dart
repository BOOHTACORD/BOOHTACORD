import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/system_activity/throttle.dart';

void main() {
  test('only successfully sent activity consumes the monotonic interval', () {
    var elapsed = Duration.zero;
    final throttle = ActivityThrottle(() => elapsed);
    expect(throttle.ready, isTrue);
    expect(throttle.ready, isTrue);
    throttle.sent();
    elapsed = const Duration(seconds: 9);
    expect(throttle.ready, isFalse);
    elapsed = const Duration(seconds: 10);
    expect(throttle.ready, isTrue);
    throttle.sent();
    elapsed = Duration.zero;
    expect(throttle.ready, isTrue);
  });
}
