import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/attempt.dart';

void main() {
  test('attempt lifecycle ignores late completion from an older socket', () {
    var started = 0, ended = 0;
    final attempts = RealtimeSocketAttempt(() => started++, () => ended++);
    final first = attempts.begin();
    expect(started, 1);
    attempts.end(first);
    attempts.end(first);
    expect(ended, 1);
    final second = attempts.begin();
    attempts.end(first);
    expect(ended, 1);
    attempts.end(second);
    expect(started, 2);
    expect(ended, 2);
  });
}
