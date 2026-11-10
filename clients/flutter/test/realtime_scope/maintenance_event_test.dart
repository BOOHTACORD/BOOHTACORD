import 'dart:convert';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const generation = '11111111-1111-4111-8111-111111111111';
const state = <String, dynamic>{
  'version': 1,
  'generation': generation,
  'revision': 1,
  'active': false,
};

void main() {
  test('valid maintenance snapshots and changes are ephemeral', () async {
    final events = <RealtimeEvent>[];
    final owner = RealtimeController(
      RealtimeApiFake(),
      SessionScope(),
      isReady: () => true,
      expire: () async {},
      invalidatePresence: () {},
      dispatch: events.add,
      recover: () {},
    );
    addTearDown(owner.dispose);
    void receive(String id, String kind, Map<String, dynamic> payload) =>
        owner.receive(
          jsonEncode({'event_id': id, 'kind': kind, 'payload': payload}),
        );
    receive('message', 'message.created', {});
    await Future<void>.delayed(Duration.zero);
    for (final kind in ['maintenance.snapshot', 'maintenance.changed']) {
      receive(kind, kind, state);
      await Future<void>.delayed(Duration.zero);
    }
    receive('decimal', 'maintenance.changed', {
      ...state,
      'version': 1.0,
      'revision': 1.0,
    });
    await Future<void>.delayed(Duration.zero);
    expect(events.map((event) => event.kind), [
      'message.created',
      'maintenance.snapshot',
      'maintenance.changed',
      'maintenance.changed',
    ]);
    expect(owner.delivery.cursor, 'message');
  });

  test(
    'malformed maintenance state closes the socket and clears the cursor',
    () async {
      final malformed = <Object?>[
        null,
        <Object?>[],
        'not-an-object',
        {'version': 1, 'generation': generation, 'revision': 1},
        {...state, 'operator': 'private'},
        {...state, 'version': 2},
        {...state, 'generation': 'invalid'},
        {...state, 'revision': 0},
        {...state, 'revision': 1.5},
        {...state, 'revision': 9007199254740992},
        {...state, 'active': 'false'},
      ];
      for (final kind in ['maintenance.snapshot', 'maintenance.changed']) {
        for (final payload in malformed) {
          final events = <RealtimeEvent>[];
          final owner = RealtimeController(
            RealtimeApiFake(),
            SessionScope(),
            isReady: () => true,
            expire: () async {},
            invalidatePresence: () {},
            dispatch: events.add,
            recover: () {},
          );
          owner.receive(
            jsonEncode({
              'event_id': 'message',
              'kind': 'message.created',
              'payload': {},
            }),
          );
          await Future<void>.delayed(Duration.zero);
          expect(owner.delivery.cursor, 'message');
          owner.connected = true;
          owner.receive(
            jsonEncode({'event_id': 'bad', 'kind': kind, 'payload': payload}),
          );
          await Future<void>.delayed(Duration.zero);
          expect(owner.connected, isFalse, reason: '$payload');
          expect(owner.delivery.cursor, isNull, reason: '$payload');
          expect(events.where((event) => event.kind == kind), isEmpty);
          owner.dispose();
        }
      }
    },
  );
}
