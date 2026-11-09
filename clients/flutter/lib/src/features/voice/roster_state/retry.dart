import 'dart:async';
import 'dart:math';

import 'controller.dart';

extension VoiceRosterRetry on VoiceRosterController {
  Future<bool> waitForRetry(int expected) async {
    // Exhausting the fast budget must not strand a healthy session forever.
    // Continue with one jittered, rate-limited retry until stopped or revoked.
    final milliseconds = retryAttempt >= retryBudget
        ? 30000
        : min(30000, retryDelay.inMilliseconds * pow(2, retryAttempt)).toInt();
    if (retryAttempt < retryBudget) retryAttempt++;
    final delay = Duration(
      milliseconds: min(
        30000,
        (milliseconds * (.8 + .4 * jitter().clamp(0, 1))).round(),
      ),
    );
    final retry = Completer<void>();
    retryDone = retry;
    retryTimer = schedule(delay, () {
      if (!retry.isCompleted) retry.complete();
    });
    await retry.future;
    if (disposed || expected != revision || !scope.capture().isActive) {
      return false;
    }
    retryTimer = null;
    retryDone = null;
    return watching;
  }

  void retryVoiceRosters() {
    if (!canRetry) return;
    stop();
    start();
    changed();
  }
}
