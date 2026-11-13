import 'dart:convert';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'roster_fixtures.dart';

void main() {
  test('invalid outer envelopes reject both roster event kinds', () async {
    for (final kind in ['voice.roster.snapshot', 'voice.roster.unavailable']) {
      for (final bad in [
        {'event_id': 'bad'},
        {'occurred_at': '2026-02-30T00:00:00Z'},
        {'extra': 'private'},
      ]) {
        final events = <RealtimeEvent>[];
        final owner = RealtimeController(
          RealtimeApiFake(),
          SessionScope(),
          isReady: () => true,
          expire: () async {},
          invalidatePresence: () {},
          dispatch: events.add,
        );
        owner.connected = true;
        owner.receive(
          jsonEncode({
            'event_id': id,
            'occurred_at': '2026-11-13T00:00:00Z',
            'kind': kind,
            'payload': kind == 'voice.roster.snapshot'
                ? snapshot()
                : {'version': 1, 'code': 'temporarily_unavailable'},
            ...bad,
          }),
        );
        await Future<void>.delayed(Duration.zero);
        expect(owner.connected, isFalse, reason: '$kind $bad');
        expect(events, isEmpty);
        owner.dispose();
      }
    }
  });
}
