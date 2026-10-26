import 'dart:async';
import 'dart:convert';

import 'controller.dart';
import '../social_hints/hints.dart';

extension RealtimeEvents on RealtimeController {
  void synchronizeDeliveryScope() {
    final server = api.transport.session.serverRevision;
    final installation = api.transport.session.telemetry.installation;
    if (deliveryTicket?.isActive != true ||
        deliveryServer != server ||
        deliveryInstallation != installation) {
      delivery.reset();
      deliveryTicket = scope.capture();
      deliveryServer = server;
      deliveryInstallation = installation;
    }
  }

  Future<void> applyEvent(RealtimeEvent event) async {
    if (deliveryTicket?.isActive != true ||
        deliveryServer != api.transport.session.serverRevision ||
        deliveryInstallation != api.transport.session.telemetry.installation)
      return;
    if (await SocialHints.forTransport(api.transport).receiveAsync(event))
      return;
    await dispatch(event);
    changed();
  }

  void receive(dynamic raw) {
    if (!admission()() || raw is! String) return;
    synchronizeDeliveryScope();
    try {
      final source = jsonDecode(raw);
      if (source is! Map<String, dynamic>) return;
      final id = source['event_id'],
          kind = source['kind'],
          payload = source['payload'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 512 ||
          kind is! String ||
          payload is! Map<String, dynamic>)
        return;
      if (kind == 'screen_viewers.changed' && payload.isNotEmpty) return;
      if (kind == 'connection.ready' || kind == 'connection.resync_required') {
        if (payload.isNotEmpty) return;
      }
      if (kind == 'connection.ready') {
        if (connected) return;
        connected = true;
        hadConnection = true;
        attempt = 0;
        readyTimeout?.cancel();
        readyTimeout = null;
        handshake?.step('ready');
        handshake?.finish('success');
        handshake = null;
        changed();
      }
      delivery.accept(
        RealtimeEvent(
          id,
          kind,
          payload,
          telemetry: RealtimeTelemetry.parse(source['telemetry']),
        ),
      );
    } catch (_) {
      // Malformed envelopes confer no authority and cannot become cursors.
    }
  }
}
