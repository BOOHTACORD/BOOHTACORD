import 'dart:async';
import 'dart:convert';

import 'controller.dart';
import '../social_hints/hints.dart';
import 'maintenance_payload.dart';
import 'roster_payload.dart';
import 'resync_payload.dart';
import 'new_envelope.dart';

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
    final active = admission();
    if (!active() || deliveryTicket?.isActive != true ||
        deliveryServer != api.transport.session.serverRevision ||
        deliveryInstallation != api.transport.session.telemetry.installation) {
      return;
    }
    final consumed = await SocialHints.forTransport(api.transport).receiveAsync(event);
    if (!active() || consumed) {
      return;
    }
    await dispatch(event);
    if (active()) changed();
  }

  void receive(dynamic raw) {
    if (!admission()()) return;
    if (raw is! String) {
      delivery.reset();
      handleClosed();
      return;
    }
    synchronizeDeliveryScope();
    try {
      final source = jsonDecode(raw);
      if (source is! Map<String, dynamic>) {
        delivery.reset();
        handleClosed();
        return;
      }
      final id = source['event_id'],
          kind = source['kind'],
          payload = source['payload'];
      if (((isMaintenanceKind(kind) || isRosterKind(kind)) &&
              !validNewRealtimeEnvelope(source)) ||
          (isMaintenanceKind(kind) && !validMaintenancePayload(payload)) ||
          (isRosterKind(kind) && !validRosterPayload(kind, payload))) {
        delivery.reset();
        handleClosed();
        return;
      }
      if (id is! String ||
          id.isEmpty ||
          id.length > 512 ||
          kind is! String ||
          payload is! Map<String, dynamic>) {
        return;
      }
      if (kind == 'screen_viewers.changed' && payload.isNotEmpty) return;
      if (kind == 'connection.ready') {
        if (payload.isNotEmpty) return;
      }
      if (kind == 'connection.resync_required' &&
          !validResyncPayload(payload)) {
        return;
      }
      if (liveness?.observe(kind, source) == false) {
        handleClosed();
        return;
      }
      if (kind == 'connection.heartbeat') return;
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
    } on FormatException {
      delivery.reset();
      handleClosed();
    } catch (_) {
      // Malformed envelopes confer no authority and cannot become cursors.
    }
  }
}
