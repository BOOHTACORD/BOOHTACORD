import 'dart:convert';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('typed resync clears the cursor and invokes recovery', () async {
    var recoveries = 0;
    final owner = RealtimeController(
      RealtimeApiFake(),
      SessionScope(),
      isReady: () => true,
      expire: () async {},
      invalidatePresence: () {},
      dispatch: (_) {},
      recover: () {
        recoveries++;
      },
    );
    addTearDown(owner.dispose);
    void receive(String id, String kind, Map<String, dynamic> payload) {
      owner.receive(
        jsonEncode({'event_id': id, 'kind': kind, 'payload': payload}),
      );
    }

    receive('message', 'message.created', {});
    await Future<void>.delayed(Duration.zero);
    expect(owner.delivery.cursor, 'message');
    for (final payload in <Map<String, dynamic>>[
      {},
      {'reason': 'invalid'},
      {'reason': 'cursor_expired', 'private': 'unexpected'},
    ]) {
      receive('bad', 'connection.resync_required', payload);
    }
    await Future<void>.delayed(Duration.zero);
    expect(recoveries, 0);
    expect(owner.delivery.cursor, 'message');
    for (final reason in [
      'event_overflow',
      'server_restart',
      'cursor_expired',
      'cursor_invalid',
      'replay_limit',
      'replay_unavailable',
    ]) {
      receive('control-$reason', 'connection.resync_required', {
        'reason': reason,
      });
      await Future<void>.delayed(Duration.zero);
    }
    expect(owner.delivery.cursor, isNull);
    expect(recoveries, 6);
  });
}
