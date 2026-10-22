import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';

import 'fakes.dart';

void main() {
  test(
    'events are deduplicated and blocked after account scope closure',
    () async {
      final scope = SessionScope();
      final events = <RealtimeEvent>[];
      final owner = RealtimeController(
        RealtimeApiFake(),
        scope,
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: events.add,
      );
      addTearDown(owner.dispose);
      final raw = jsonEncode({
        'event_id': 'one',
        'kind': 'connection.ready',
        'payload': {},
      });
      owner.receive(raw);
      owner.receive(raw);
      owner.receive('{invalid');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(2));
      expect(owner.connected, isTrue);
      scope.close();
      owner.receive(jsonEncode({'event_id': 'two', 'kind': 'channel.updated'}));
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(2));
    },
  );
}
