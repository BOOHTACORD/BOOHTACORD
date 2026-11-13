import 'dart:convert';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/new_envelope.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/guest.dart';
import 'package:boohtacord_desktop/src/features/session/maintenance_socket/state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const id = '11111111-1111-4111-8111-111111111111';
const good = <String, dynamic>{
  'event_id': id,
  'occurred_at': '2026-11-13T00:00:00Z',
  'kind': 'maintenance.snapshot',
  'payload': {'version': 1, 'generation': id, 'revision': 1, 'active': false},
};

void main() {
  test('valid new envelopes may carry strict telemetry', () {
    expect(validNewRealtimeEnvelope(good), isTrue);
    expect(
      validNewRealtimeEnvelope({
        ...good,
        'telemetry': {
          'reference': 'local',
          'trace_id': '1' * 32,
          'span_id': '2' * 16,
        },
      }),
      isTrue,
    );
    expect(
      validNewRealtimeEnvelope({
        ...good,
        'telemetry': {
          'reference': 'local',
          'trace_id': '1' * 32,
          'span_id': '2' * 16,
          'extra': true,
        },
      }),
      isFalse,
    );
  });
  test('invalid new envelopes close the authenticated socket', () async {
    final invalid = <Map<String, dynamic>>[
      {...good, 'event_id': 'invalid'},
      {...good, 'occurred_at': '2026-02-30T00:00:00Z'},
      {...good, 'occurred_at': null},
      {...good, 'unexpected': 'private'},
      {...good, 'telemetry': null},
      {
        ...good,
        'telemetry': {
          'reference': 'x',
          'trace_id': '0' * 32,
          'span_id': '1' * 16,
        },
      },
    ];
    for (final value in invalid) {
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
      owner.receive(jsonEncode(value));
      await Future<void>.delayed(Duration.zero);
      expect(owner.connected, isFalse, reason: '$value');
      expect(events, isEmpty);
      owner.dispose();
    }
  });

  test('guest returns to unknown for invalid new envelope', () async {
    final state = MaintenanceSocketState(), socket = SocketFake();
    final guest = MaintenanceGuestSocket(state, () async => socket);
    guest.start();
    await Future<void>.delayed(Duration.zero);
    socket.events.add(
      jsonEncode({...good, 'kind': 'connection.ready', 'payload': {}}),
    );
    socket.events.add(jsonEncode(good));
    await Future<void>.delayed(Duration.zero);
    expect(state.known, isTrue);
    socket.events.add(
      jsonEncode({
        ...good,
        'kind': 'maintenance.changed',
        'event_id': 'invalid',
        'payload': {
          'version': 1,
          'generation': id,
          'revision': 2,
          'active': true,
        },
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(state.known, isFalse);
    await guest.stop();
    state.dispose();
  });
}
