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
      'channels': [
        {
          'channel_id': '22222222-2222-4222-8222-222222222222',
          'participants': [],
        },
      ],
    });

void main() {
  test('invalid socket snapshot remains stale, expires and retries the shared owner', () async {
    final scope = SessionScope();
    final timers = <ScheduledRosterTimer>[];
    var retries = 0;
    final owner = VoiceRosterController(
      scope,
      isReady: () => true,
      hasUser: () => true,
      onSharedRetry: () => retries++,
      schedule: (delay, callback) {
        final timer = ScheduledRosterTimer(delay, callback);
        timers.add(timer);
        return timer;
      },
    );
    addTearDown(owner.dispose);
    owner.start();
    owner.sharedSocketStart();
    owner.acceptSocketEvent(snapshot(1));
    owner.acceptSocketEvent(
      const RealtimeEvent('event', 'voice.roster.snapshot', {}),
    );
    expect(owner.phase, VoiceRosterPhase.stale);
    expect(owner.voiceRosters, hasLength(1));
    timers.last.fire();
    expect(owner.phase, VoiceRosterPhase.unavailable);
    expect(owner.voiceRosters, isNull);
    owner.retryVoiceRosters();
    await owner.refreshVoiceRosters();
    expect(retries, 2);
    owner.stop();
    owner.acceptSocketEvent(snapshot(2));
    expect(owner.voiceRosters, isNull);
  });
}
