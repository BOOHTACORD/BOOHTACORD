import 'dart:async';

import 'controller.dart';
import '../../telemetry/action_scope/action.dart';
import '../../../services/client_telemetry.dart';

extension RealtimeConnection on RealtimeController {
  Future<void> connect() async {
    if (deliveryServer != null &&
        (deliveryServer != api.transport.session.serverRevision ||
            deliveryTicket?.isActive != true)) {
      await close();
    }
    final active = admission();
    if (!api.realtimeEnabled || !active() || socket != null || connecting) {
      return;
    }
    synchronizeDeliveryScope();
    retry?.cancel();
    retry = null;
    connecting = true;
    changed();
    handshake?.finish('superseded');
    final flow = ActionScope(
      hadConnection ? 'realtime.reconnect' : 'realtime.connect',
      api.transport.session.telemetry,
      enabled: ClientTelemetry.enabled,
    );
    handshake = flow;
    flow.step('connect');
    try {
      final opened = await flow.run(
        () => api.openRealtime(after: delivery.cursor),
      );
      if (!active()) {
        flow.finish('cancelled', reason: 'generation_changed');
        await opened.close();
        return;
      }
      socket = opened;
      readyTimeout?.cancel();
      readyTimeout = Timer(const Duration(seconds: 15), () {
        if (active() && identical(socket, opened) && !connected) handleClosed();
      });
      subscription = opened.listen(
        (raw) {
          if (active() && identical(socket, opened)) receive(raw);
        },
        onDone: () {
          if (active() && identical(socket, opened)) handleClosed();
        },
        onError: (_) {
          if (active() && identical(socket, opened)) handleClosed();
        },
        cancelOnError: true,
      );
    } catch (_) {
      flow.finish('failed', reason: 'network');
      if (active()) scheduleRetry();
    } finally {
      if (active()) connecting = false;
    }
  }
}
