import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';

import 'support.dart';

const generation = '11111111-1111-4111-8111-111111111111';
const channel = '22222222-2222-4222-8222-222222222222';

RealtimeEvent snapshot(int revision, {bool empty = false}) =>
    RealtimeEvent('event', 'voice.roster.snapshot', {
      'version': 1,
      'generation': generation,
      'revision': revision,
      'observed_at': '2026-11-09T00:00:00Z',
      'channels': empty
          ? []
          : [
              {'channel_id': channel, 'participants': []},
            ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'shared roster keeps states, guards revision and retries without SSE',
    () {
      final api = RosterApi(), scope = SessionScope();
      final timers = <ScheduledRosterTimer>[];
      var retries = 0;
      final owner = VoiceRosterController(
        api,
        scope,
        isReady: () => true,
        hasUser: () => true,
        message: (e) => '$e',
        sharedSocket: true,
        onSharedRetry: () => retries++,
        schedule: (delay, callback) {
          final timer = ScheduledRosterTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      owner.start();
      owner.sharedSocketStart();
      expect(api.streams, isEmpty);
      expect(owner.phase, VoiceRosterPhase.initialLoading);
      owner.acceptSocketEvent(snapshot(9));
      expect(owner.voiceRosters, hasLength(1));
      expect(owner.phase, VoiceRosterPhase.fresh);
      owner.acceptSocketEvent(snapshot(8, empty: true));
      expect(owner.voiceRosters, hasLength(1));
      owner.sharedSocketEnd();
      expect(owner.phase, VoiceRosterPhase.stale);
      owner.retryVoiceRosters();
      expect(retries, 1);
      owner.sharedSocketStart();
      owner.acceptSocketEvent(snapshot(1, empty: true));
      expect(owner.voiceRosters, isEmpty);
      owner.stop();
      owner.acceptSocketEvent(snapshot(2));
      expect(owner.voiceRosters, isNull);
      expect(api.streams, isEmpty);
      owner.dispose();
    },
  );

  test('missing initial snapshot becomes unavailable and can recover', () {
    final api = RosterApi(), scope = SessionScope();
    final timers = <ScheduledRosterTimer>[];
    final owner = VoiceRosterController(
      api,
      scope,
      isReady: () => true,
      hasUser: () => true,
      message: (e) => '$e',
      sharedSocket: true,
      onSharedRetry: () {},
      schedule: (delay, callback) {
        final timer = ScheduledRosterTimer(delay, callback);
        timers.add(timer);
        return timer;
      },
    );
    owner.start();
    owner.sharedSocketStart();
    timers.first.fire();
    expect(owner.phase, VoiceRosterPhase.unavailable);
    owner.acceptSocketEvent(snapshot(1, empty: true));
    expect(owner.phase, VoiceRosterPhase.fresh);
    owner.dispose();
  });

  test('old socket cannot update a replaced account scope', () {
    final api = RosterApi(), scope = SessionScope();
    final owner = VoiceRosterController(
      api,
      scope,
      isReady: () => true,
      hasUser: () => true,
      message: (e) => '$e',
      sharedSocket: true,
      onSharedRetry: () {},
    );
    owner.start();
    owner.sharedSocketStart();
    scope.begin();
    owner.acceptSocketEvent(snapshot(1));
    expect(owner.voiceRosters, isNull);
    expect(owner.phase, VoiceRosterPhase.initialLoading);
    owner.dispose();
  });
}
