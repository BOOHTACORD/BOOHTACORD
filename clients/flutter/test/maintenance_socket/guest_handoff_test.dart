import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/guest.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/state.dart';

import '../realtime_scope/fakes.dart';

class SlowCloseSocket extends SocketFake {
  final release = Completer<void>();
  @override
  Future<void> close([int? code, String? reason]) async {
    await release.future;
    await super.close(code, reason);
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('handoff waits for an already-closing guest socket', () async {
    final state = MaintenanceSocketState(), socket = SlowCloseSocket();
    final guest = MaintenanceGuestSocket(state, () async => socket);
    guest.start();
    await flush();
    socket.events.add(
      jsonEncode({
        'event_id': 'event',
        'kind': 'message.created',
        'occurred_at': '2026-11-09T00:00:00Z',
        'payload': {},
      }),
    );
    await flush();
    var stopped = false;
    final stopping = guest.stop().then((_) => stopped = true);
    await flush();
    expect(stopped, isFalse);
    socket.release.complete();
    await stopping;
    expect(socket.closed, isTrue);
    state.dispose();
  });

  test('handoff aborts an in-flight guest handshake', () async {
    final state = MaintenanceSocketState(), opening = Completer<WebSocket>();
    var aborts = 0;
    final guest = MaintenanceGuestSocket(
      state,
      () => opening.future,
      abortOpen: () => aborts++,
    );
    guest.start();
    var stopped = false;
    final stopping = guest.stop().then((_) => stopped = true);
    await flush();
    expect(aborts, 1);
    expect(stopped, isFalse);
    final old = SocketFake();
    opening.complete(old);
    await stopping;
    await flush();
    expect(old.closed, isTrue);
    state.dispose();
  });

  test(
    'handoff fails closed if an opening handshake cannot be canceled',
    () async {
      final state = MaintenanceSocketState(), opening = Completer<WebSocket>();
      final guest = MaintenanceGuestSocket(
        state,
        () => opening.future,
        abortOpen: () {},
      );
      guest.start();
      await expectLater(guest.stop(), throwsA(isA<TimeoutException>()));
      final old = SocketFake();
      opening.complete(old);
      await flush();
      expect(old.closed, isTrue);
      state.dispose();
    },
  );
}
