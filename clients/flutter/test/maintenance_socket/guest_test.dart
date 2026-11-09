import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/guest.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/state.dart';

import '../realtime_scope/fakes.dart';
import '../voice_roster_state/support.dart' show ScheduledRosterTimer;

String event(String kind, Map<String, dynamic> payload) => jsonEncode({
  'event_id': 'event',
  'kind': kind,
  'occurred_at': '2026-11-09T00:00:00Z',
  'payload': payload,
});
Map<String, dynamic> snapshot(bool active) => {
  'version': 1,
  'generation': '11111111-1111-4111-8111-111111111111',
  'revision': 1,
  'active': active,
};
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'guest requires ready and snapshot, then stops without late updates',
    () async {
      final state = MaintenanceSocketState(), socket = SocketFake();
      final guest = MaintenanceGuestSocket(state, () async => socket);
      guest.start();
      await flush();
      socket.events.add(event('connection.ready', {}));
      socket.events.add(event('maintenance.snapshot', snapshot(true)));
      await flush();
      expect(state.known, isTrue);
      expect(state.active, isTrue);
      await guest.stop();
      expect(socket.closed, isTrue);
      expect(state.known, isFalse);
      state.dispose();
    },
  );

  test(
    'a timed-out late open is closed and cannot reclaim ownership',
    () async {
      final state = MaintenanceSocketState(), opening = Completer<WebSocket>();
      final timers = <ScheduledRosterTimer>[];
      final guest = MaintenanceGuestSocket(
        state,
        () => opening.future,
        schedule: (delay, callback) {
          final timer = ScheduledRosterTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      guest.start();
      timers.first.fire();
      final old = SocketFake();
      opening.complete(old);
      await flush();
      expect(old.closed, isTrue);
      expect(state.known, isFalse);
      expect(timers.where((timer) => timer.isActive), isNotEmpty);
      await guest.stop();
      state.dispose();
    },
  );

  test('unrecognized private event closes the public connection', () async {
    final state = MaintenanceSocketState(), socket = SocketFake();
    final timers = <ScheduledRosterTimer>[];
    final guest = MaintenanceGuestSocket(
      state,
      () async => socket,
      schedule: (delay, callback) {
        final timer = ScheduledRosterTimer(delay, callback);
        timers.add(timer);
        return timer;
      },
    );
    guest.start();
    await flush();
    socket.events.add(event('message.created', {}));
    await flush();
    expect(socket.closed, isTrue);
    expect(state.known, isFalse);
    await guest.stop();
    state.dispose();
  });

}
