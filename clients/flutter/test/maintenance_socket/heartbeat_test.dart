import 'dart:convert';
import 'dart:async';

import 'package:boohtacord_desktop/src/features/session/maintenance_socket/guest.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../realtime_scope/heartbeat_liveness_test.dart' show HeartbeatSocket;

String event(String kind, Map<String, dynamic> payload) => jsonEncode({
  'event_id': '11111111-1111-4111-8111-111111111111',
  'kind': kind,
  'occurred_at': '2026-11-13T00:00:00Z',
  'payload': payload,
});

void main() {
  testWidgets('guest reconnects only after negotiated heartbeat stops', (
    tester,
  ) async {
    final state = MaintenanceSocketState();
    final socket = HeartbeatSocket();
    final guest = MaintenanceGuestSocket(state, () async => socket);
    guest.start();
    await tester.pump();
    socket.events.add(event('connection.ready', {}));
    socket.events.add(
      event('maintenance.snapshot', {
        'version': 1,
        'generation': '11111111-1111-4111-8111-111111111111',
        'revision': 1,
        'active': false,
      }),
    );
    await tester.pump();
    expect(state.known, isTrue);
    await tester.pump(const Duration(seconds: 30));
    socket.events.add(event('connection.heartbeat', {}));
    await tester.pump();
    expect(state.known, isTrue);
    await tester.pump(const Duration(seconds: 30));
    expect(socket.closed, isFalse);
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(state.known, isFalse);
    unawaited(guest.stop());
    await tester.pump();
    state.dispose();
  });
}
