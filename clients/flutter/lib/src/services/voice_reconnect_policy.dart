import 'dart:math' as math;

import 'package:livekit_client/livekit_client.dart' as livekit;

const voiceReconnectAttemptLimit = livekit.voiceReconnectAttemptLimit;

/// LiveKit's Flutter SDK reports the next reconnect attempt as a 1-based value.
/// The web client's BoundedVoiceReconnectPolicy permits retry counts 0–5,
/// which is six attempts total; the seventh scheduled attempt must be stopped.
bool shouldAllowVoiceReconnectAttempt(int attempt) =>
    attempt >= 1 && attempt <= voiceReconnectAttemptLimit;


/// Client-level recovery begins when the SDK exhausts its six short retries.
/// The retry budget is intentionally unbounded; only the interval is capped.
Duration voiceLongRecoveryDelay(int failures, {double? randomValue}) {
  final jitter = randomValue ?? math.Random().nextDouble();
  if (jitter < 0 || jitter >= 1 || !jitter.isFinite) {
    throw RangeError.range(jitter, 0, 1, 'randomValue', 'must be < 1');
  }
  final backoff = (1000 * (1 << failures.clamp(0, 5))).clamp(0, 30000);
  return Duration(milliseconds: (backoff * (0.8 + jitter * 0.4)).floor());
}
