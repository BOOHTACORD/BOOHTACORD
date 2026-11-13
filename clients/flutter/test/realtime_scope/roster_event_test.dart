import 'dart:convert';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

import 'roster_fixtures.dart';

void main() {
  test('valid roster events stay ephemeral', () async {
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
    var sequence = 0;
    void receive(String eventID, String kind, Object payload) => owner.receive(
      jsonEncode({
        'event_id': kind.startsWith('voice.roster.')
            ? '11111111-1111-4111-8111-${(++sequence).toString().padLeft(12, '0')}'
            : eventID,
        'occurred_at': '2026-11-13T00:00:00Z',
        'kind': kind,
        'payload': payload,
      }),
    );
    receive('message', 'message.created', {});
    await Future<void>.delayed(Duration.zero);
    receive('roster', 'voice.roster.snapshot', snapshot());
    receive('empty', 'voice.roster.snapshot', {...snapshot(), 'channels': []});
    receive('failure', 'voice.roster.unavailable', {
      'version': 1,
      'code': 'temporarily_unavailable',
    });
    await Future<void>.delayed(Duration.zero);
    expect(events.map((event) => event.kind), [
      'message.created',
      'voice.roster.snapshot',
      'voice.roster.snapshot',
      'voice.roster.unavailable',
    ]);
    expect(owner.delivery.cursor, 'message');
  });

  test(
    'malformed roster closes the connection and clears the cursor',
    () async {
      for (final payload in <Object?>[
        null,
        {...snapshot(), 'revision': 0},
        {...snapshot(), 'revision': 9007199254740992},
        {...snapshot(), 'observed_at': '2026-02-30T00:00:00Z'},
        {...snapshot(), 'extra': 'private'},
        {
          ...snapshot(),
          'channels': [
            {
              'channel_id': id,
              'participants': [
                {
                  'account_id': id,
                  'display_name': 'A',
                  'screen_sharing': false,
                  'microphone_muted': true,
                  'lease_id': id,
                },
              ],
            },
          ],
        },
      ]) {
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
        owner.connected = true;
        owner.receive(
          jsonEncode({
            'event_id': id,
            'occurred_at': '2026-11-13T00:00:00Z',
            'kind': 'voice.roster.snapshot',
            'payload': payload,
          }),
        );
        await Future<void>.delayed(Duration.zero);
        expect(owner.connected, isFalse, reason: '$payload');
        expect(owner.delivery.cursor, isNull, reason: '$payload');
        expect(
          events.where((event) => event.kind == 'voice.roster.snapshot'),
          isEmpty,
        );
        owner.dispose();
      }
    },
  );
}
