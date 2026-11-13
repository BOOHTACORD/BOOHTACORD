import 'dart:convert';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/liveness.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class HeartbeatSocket extends SocketFake {
  @override
  String? get protocol => 'boohtacord.heartbeat.v1';
}

String envelope(String kind) => jsonEncode({
  'event_id': '11111111-1111-4111-8111-111111111111',
  'kind': kind,
  'occurred_at': '2026-11-13T00:00:00Z',
  'payload': <String, dynamic>{},
});

void main() {
  testWidgets('unvalidated event cannot extend the heartbeat deadline', (
    tester,
  ) async {
    var timeouts = 0;
    final watch = RealtimeLiveness(true, () => timeouts++);
    watch.observe('connection.ready', {});
    await tester.pump(const Duration(seconds: 40));
    watch.observe('unknown.event', {});
    await tester.pump(const Duration(seconds: 6));
    expect(timeouts, 1);
    watch.stop();
  });
  testWidgets('resuming after suspended timers detects stale connection', (
    tester,
  ) async {
    var now = DateTime.utc(2026);
    var timeouts = 0;
    final watch = RealtimeLiveness(true, () => timeouts++, now: () => now);
    watch.observe('connection.ready', {});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 46));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(timeouts, 1);
    watch.stop();
  });
  testWidgets('heartbeat delays silent socket recovery without dispatch', (
    tester,
  ) async {
    final api = RealtimeApiFake();
    final socket = HeartbeatSocket();
    final dispatched = <String?>[];
    final owner = RealtimeController(
      api,
      SessionScope(),
      isReady: () => true,
      expire: () async {},
      invalidatePresence: () {},
      dispatch: (e) => dispatched.add(e.kind),
    );
    api.opening.complete(socket);
    await owner.connect();
    socket.events.add(envelope('connection.ready'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    socket.events.add(envelope('connection.heartbeat'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(socket.closed, isFalse);
    expect(dispatched, isNot(contains('connection.heartbeat')));
    await tester.pump(const Duration(seconds: 16));
    expect(socket.closed, isTrue);
    expect(owner.connected, isFalse);
    await owner.close();
    owner.dispose();
  });

  testWidgets('malformed heartbeat closes the negotiated socket', (
    tester,
  ) async {
    final api = RealtimeApiFake();
    final socket = HeartbeatSocket();
    final owner = RealtimeController(
      api,
      SessionScope(),
      isReady: () => true,
      expire: () async {},
      invalidatePresence: () {},
      dispatch: (_) {},
    );
    api.opening.complete(socket);
    await owner.connect();
    socket.events.add(envelope('connection.ready'));
    await tester.pump();
    socket.events.add(
      jsonEncode({
        'event_id': 'not-a-uuid',
        'kind': 'connection.heartbeat',
        'occurred_at': '2026-11-13T00:00:00Z',
        'payload': {},
      }),
    );
    await tester.pump();
    expect(socket.closed, isTrue);
    await owner.close();
    owner.dispose();
  });
}
