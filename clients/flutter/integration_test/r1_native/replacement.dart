import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'harness.dart';

extension R1Replacement on R1Harness {
  Future<void> replacement() async {
    await real(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    final held = api.holdTopology();
    api.forceResync = true;
    await real(() async {
      await app.realtime.socket!.close();
      await held.reached.future.timeout(const Duration(seconds: 20));
    });
    final reads = api.topologyReads;
    await realPeer(peer.leaveVoice);
    await addFreshChannel('R1 Fresh Socket');
    api.forceResync = true;
    await real(() => app.realtime.socket!.close());
    await wait(
      () => fresh && participants == 0 && hasChannel('R1 Fresh Socket'),
    );
    expect(api.topologyReads, greaterThan(reads));
    expect(held.release.isCompleted, isFalse);
    await capture('replacement-before-old-response');
    held.finish();
    for (var i = 0; i < 10; i++) {
      await real(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      expect(participants, 0);
      expect(hasChannel('R1 Fresh Socket'), isTrue);
    }
    await capture('replacement-after-old-response');
    await real(steady);
    report['replacement_before_old_response'] = true;
    report['old_response_no_ghost'] = true;
  }

  Future<void> processRestart() async {
    final generation = app.voiceRoster.sharedGeneration,
        socket = app.realtime.socket;
    await real(restartApi);
    await wait(
      () =>
          fresh &&
          app.realtime.socket != socket &&
          app.voiceRoster.sharedGeneration != generation &&
          participants == 0,
    );
    await capture('api-restarted-fresh');
    await real(steady);
    report['api_restart_fresh_generation'] = true;
  }
}
