import 'dart:async';

import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_support.dart';
import 'support.dart';

RealtimeEvent snapshot({bool empty = false}) =>
    RealtimeEvent('event', 'voice.roster.snapshot', {
      'version': 1,
      'generation': '11111111-1111-4111-8111-111111111111',
      'revision': 1,
      'observed_at': '2026-11-09T00:00:00Z',
      'channels': empty
          ? []
          : [
              {
                'channel_id': '22222222-2222-4222-8222-222222222222',
                'participants': [],
              },
            ],
    });
const unavailable = RealtimeEvent('event', 'voice.roster.unavailable', {
  'version': 1,
  'code': 'temporarily_unavailable',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app routes unavailable and a replacement snapshot without a separate stream', () async {
    final api = RosterApi(), state = ready(api);
    state.voiceRoster.start();
    state.realtime.onSocketStart?.call();
    await state.realtime.dispatch(unavailable);
    expect(state.voiceRosterError, isNotNull);
    expect(state.voiceRosters, isNull);
    await state.realtime.dispatch(snapshot(empty: true));
    expect(state.voiceRosters, isEmpty);
    expect(state.voiceRoster.phase, VoiceRosterPhase.fresh);
    expect(api.rosterReads, 0);
  });

  test('socket loss retains the roster as stale and expires it', () async {
    final api = RosterApi(), state = ready(api);
    state.voiceRoster.start();
    state.realtime.onSocketStart?.call();
    await state.realtime.dispatch(snapshot());
    expect(state.voiceRosters, hasLength(1));
    final expired = Completer<void>();
    state.addListener(() {
      if (state.voiceRoster.phase == VoiceRosterPhase.unavailable &&
          !expired.isCompleted) {
        expired.complete();
      }
    });
    state.realtime.onSocketEnd?.call();
    expect(state.voiceRoster.phase, VoiceRosterPhase.stale);
    await expired.future.timeout(const Duration(seconds: 2));
    expect(state.voiceRosters, isNull);
    expect(api.rosterReads, 0);
  });

  test('new socket snapshot cancels retained-state expiration', () async {
    final api = RosterApi(), state = ready(api);
    state.voiceRoster.start();
    state.realtime.onSocketStart?.call();
    await state.realtime.dispatch(snapshot(empty: true));
    state.realtime.onSocketEnd?.call();
    state.realtime.onSocketStart?.call();
    await state.realtime.dispatch(snapshot());
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(state.voiceRosters, hasLength(1));
    expect(state.voiceRoster.phase, VoiceRosterPhase.fresh);
    expect(api.rosterReads, 0);
  });
}
