import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_state/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import '../realtime_scope/fakes.dart';

String wire(String kind, Map<String, dynamic> payload) => jsonEncode({
  'event_id': 'event',
  'kind': kind,
  'occurred_at': '2026-11-09T00:00:00Z',
  'payload': payload,
});
Map<String, dynamic> data(int revision, bool active) => {
  'version': 1,
  'generation': '11111111-1111-4111-8111-111111111111',
  'revision': revision,
  'active': active,
};
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'hands public maintenance to auth and returns to public after logout',
    () async {
      final sockets = <SocketFake>[];
      final controller = MaintenanceController(
        ApiClient(),
        openGuest: () async {
          final socket = SocketFake();
          sockets.add(socket);
          return socket;
        },
      );
      await controller.useGuest();
      await flush();
      sockets.single.events.add(wire('connection.ready', {}));
      sockets.single.events.add(wire('maintenance.snapshot', data(1, true)));
      await flush();
      expect(controller.known, isTrue);
      expect(controller.active, isTrue);
      await controller.useAuthenticated();
      expect(sockets.single.closed, isTrue);
      expect(controller.known, isFalse);
      expect(controller.active, isTrue);
      controller.authSocketStart();
      expect(
        controller.acceptRealtimeEvent(
          RealtimeEvent('event', 'maintenance.snapshot', data(1, true)),
        ),
        isTrue,
      );
      expect(
        controller.acceptRealtimeEvent(
          RealtimeEvent('event', 'maintenance.changed', data(2, false)),
        ),
        isTrue,
      );
      expect(controller.known, isTrue);
      expect(controller.active, isFalse);
      controller.authSocketEnd();
      expect(controller.known, isFalse);
      await controller.useGuest();
      await flush();
      expect(sockets, hasLength(2));
      sockets.last.events.add(wire('connection.ready', {}));
      sockets.last.events.add(wire('maintenance.snapshot', data(2, false)));
      await flush();
      expect(controller.known, isTrue);
      controller.dispose();
    },
  );
}
