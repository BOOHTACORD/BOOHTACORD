import 'controller.dart';

extension RealtimeCleanup on RealtimeController {
  Future<void> close() async {
    handshake?.finish('cancelled', reason: 'disposed');
    handshake = null;
    generation++;
    readyTimeout?.cancel();
    readyTimeout = null;
    attempt = 0;
    retry?.cancel();
    retry = null;
    final previousSubscription = subscription;
    final previousSocket = socket;
    subscription = null;
    socket = null;
    connected = false;
    connecting = false;
    checkingSession = false;
    delivery.reset();
    deliveryTicket = null;
    deliveryServer = null;
    if (!disposed) {
      invalidatePresence();
      changed();
    }
    try {
      await previousSubscription?.cancel();
    } finally {
      await previousSocket?.close();
    }
  }
}
