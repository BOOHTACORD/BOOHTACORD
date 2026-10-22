import 'dart:async';

import 'controller.dart';

extension RealtimeRecovery on RealtimeController {
  void retryNow() {
    if (!admission()()) return;
    if (socket != null || connecting) return;
    retry?.cancel();
    retry = null;
    unawaited(connect());
  }

  void handleClosed() {
    handshake?.finish('failed', reason: 'network');
    handshake = null;
    readyTimeout?.cancel();
    readyTimeout = null;
    delivery.disconnected();
    final previous = socket;
    final previousSubscription = subscription;
    if (previousSubscription != null) unawaited(previousSubscription.cancel());
    generation++;
    socket = null;
    subscription = null;
    connected = false;
    connecting = false;
    checkingSession = false;
    if (previous != null) unawaited(previous.close().catchError((Object _) {}));
    invalidatePresence();
    changed();
    unawaited(checkSession());
  }

  Future<void> checkSession() async {
    final active = admission();
    if (!active() || checkingSession) return;
    checkingSession = true;
    try {
      final account = await api.currentSession();
      if (!active()) return;
      if (account == null) {
        await expire();
        return;
      }
    } catch (_) {
      // A transient REST failure does not establish expiration.
    } finally {
      if (active()) checkingSession = false;
    }
    if (active()) scheduleRetry();
  }

  void scheduleRetry() {
    final active = admission();
    if (!active() || retry != null || socket != null || connecting) return;
    invalidatePresence();
    final ceilingMs = (1000 * (1 << attempt.clamp(0, 5))).clamp(1000, 30000);
    final delay = Duration(
      milliseconds: (ceilingMs * (0.5 + jitter().clamp(0, 1) * 0.5)).round(),
    );
    attempt = (attempt + 1).clamp(0, 30);
    retry = Timer(delay, () {
      retry = null;
      if (active()) unawaited(connect());
    });
    changed();
  }
}
