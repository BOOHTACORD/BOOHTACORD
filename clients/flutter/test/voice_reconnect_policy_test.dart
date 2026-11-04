import 'package:boohtacord_desktop/src/services/voice_reconnect_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows the six web-policy retry attempts and rejects the seventh', () {
    expect([1, 2, 3, 4, 5, 6].every(shouldAllowVoiceReconnectAttempt), isTrue);
    expect(shouldAllowVoiceReconnectAttempt(7), isFalse);
    expect(shouldAllowVoiceReconnectAttempt(10), isFalse);
  });

  test('long recovery retries with capped jittered backoff even after many failures', () {
    final delays = [0, 1, 2, 3, 4, 5, 6, 100].map(
      (failure) => voiceLongRecoveryDelay(failure, randomValue: 0).inMilliseconds,
    ).toList();
    expect(delays, [800, 1600, 3200, 6400, 12800, 24000, 24000, 24000]);
  });
}

