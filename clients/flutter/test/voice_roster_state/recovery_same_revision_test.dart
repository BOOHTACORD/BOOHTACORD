import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';

import 'support.dart';

RealtimeEvent snapshot(int revision) =>
    RealtimeEvent('event', 'voice.roster.snapshot', {
      'version': 1,
      'generation': '11111111-1111-4111-8111-111111111111',
      'revision': revision,
      'observed_at': '2026-11-09T00:00:00Z',
      'channels': [],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'recovers unchanged revision after unavailable and rejects older state',
    () {
      final timers = <ScheduledRosterTimer>[];
      final owner = VoiceRosterController(
        SessionScope(),
        isReady: () => true,
        hasUser: () => true,
        schedule: (delay, callback) {
          final timer = ScheduledRosterTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      owner.start();
      owner.sharedSocketStart();
      owner.acceptSocketEvent(snapshot(9));
      owner.acceptSocketEvent(
        RealtimeEvent('event', 'voice.roster.unavailable', {
          'version': 1,
          'code': 'temporarily_unavailable',
        }),
      );
      expect(owner.phase, VoiceRosterPhase.stale);
      owner.acceptSocketEvent(snapshot(8));
      expect(owner.phase, VoiceRosterPhase.stale);
      owner.acceptSocketEvent(snapshot(9));
      expect(owner.phase, VoiceRosterPhase.fresh);
      for (final timer in timers) {
        timer.fire();
      }
      expect(owner.phase, VoiceRosterPhase.fresh);
      owner.acceptSocketEvent(
        RealtimeEvent('event', 'voice.roster.unavailable', {
          'version': 1,
          'code': 'temporarily_unavailable',
        }),
      );
      timers.last.fire();
      expect(owner.phase, VoiceRosterPhase.unavailable);
      owner.acceptSocketEvent(snapshot(8));
      expect(owner.phase, VoiceRosterPhase.unavailable);
      owner.acceptSocketEvent(snapshot(9));
      expect(owner.phase, VoiceRosterPhase.fresh);
      owner.dispose();
    },
  );
}
