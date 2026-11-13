import 'dart:async';
import 'dart:io';

import 'controller.dart';
import 'open_deadline.dart';
import 'liveness.dart';
import '../../telemetry/action_scope/action.dart';
import '../../../services/client_telemetry.dart';

extension RealtimeConnection on RealtimeController {
  Future<void> connect() async {
    if (deliveryServer != null &&
        (deliveryServer != api.transport.session.serverRevision ||
            deliveryInstallation !=
                api.transport.session.telemetry.installation ||
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
    final attemptToken = socketAttempt.begin();
    handshake?.finish('superseded');
    final flow = ActionScope(
      hadConnection ? 'realtime.reconnect' : 'realtime.connect',
      api.transport.session.telemetry,
      enabled: ClientTelemetry.enabled,
    );
    handshake = flow;
    flow.step('connect');
    final client = HttpClient();
    openingClient = client;
    final elapsed = Stopwatch()..start();
    var failed = false;
    var accepted = false;
    try {
      final deadline = RealtimeOpenDeadline(
        flow.run(
          () => api.openRealtime(after: delivery.cursor, client: client),
        ),
        client,
      );
      openingDeadline = deadline;
      final opened = await deadline.result.future;
      if (!active()) {
        flow.finish('cancelled', reason: 'generation_changed');
        await opened.close();
        return;
      }
      socket = opened;
      liveness = RealtimeLiveness(opened.protocol == heartbeatProtocol, () {
        if (active() && identical(socket, opened)) handleClosed();
      });
      readyTimeout?.cancel();
      final remaining = const Duration(seconds: 15) - elapsed.elapsed;
      readyTimeout = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        () {
          if (active() && identical(socket, opened) && !connected) {
            handleClosed();
          }
        },
      );
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
      accepted = true;
    } catch (_) {
      flow.finish('failed', reason: 'network');
      failed = true;
    } finally {
      if (identical(openingDeadline?.client, client)) openingDeadline = null;
      if (identical(openingClient, client)) openingClient = null;
      client.close();
      if (!accepted) socketAttempt.end(attemptToken);
      if (active()) {
        connecting = false;
        if (failed) scheduleRetry();
      }
    }
  }
}
