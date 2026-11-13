import 'controller.dart';

extension RealtimeManualReconnect on RealtimeController {
  Future<void> reconnectNow() async {
    if (!admission()()) return;
    openingDeadline?.cancel();
    openingDeadline = null;
    openingClient?.close(force: true);
    openingClient = null;
    generation++;
    final active = admission();
    socketAttempt.end();
    handshake?.finish('cancelled', reason: 'manual_retry');
    handshake = null;
    readyTimeout?.cancel();
    readyTimeout = null;
    retry?.cancel();
    retry = null;
    delivery.disconnected();
    final previous = socket;
    final previousSubscription = subscription;
    socket = null;
    subscription = null;
    connected = false;
    connecting = false;
    checkingSession = false;
    invalidatePresence();
    changed();
    try {
      await previousSubscription?.cancel();
    } finally {
      await previous?.close();
    }
    if (active()) await connect();
  }
}
