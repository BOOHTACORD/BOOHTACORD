import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';

import 'fixtures.dart';
import 'harness.dart';

extension R1Account on R1Harness {
  Future<void> accountSwitch() async {
    await joinPeer();
    await wait(() => fresh && participants == 1);
    final held = api.holdTopology();
    api.forceResync = true;
    await real(() async {
      await app.realtime.socket!.close();
      await held.reached.future.timeout(const Duration(seconds: 20));
    });
    await realPeer(peer.leaveVoice);
    await addFreshChannel('R1 Fresh Account');
    await real(app.session.logout);
    await wait(() => app.phase == AppPhase.signedOut);
    await real(
      () =>
          app.authenticate('qa_r1_member', R1Harness.password, register: false),
    );
    await wait(
      () =>
          app.phase == AppPhase.ready &&
          fresh &&
          hasChannel('R1 Fresh Account'),
    );
    await real(() => app.workspace.selectChannel(voice));
    expect(participants, 0);
    expect(app.user!.accountId, peer.user!.accountId);
    expect(held.release.isCompleted, isFalse);
    held.finish();
    for (var i = 0; i < 10; i++) {
      await real(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      expect(app.user!.accountId, peer.user!.accountId);
      expect(hasChannel('R1 Fresh Account'), isTrue);
      expect(participants, 0);
    }
    await capture('new-account-old-response-ignored');
    await real(steady);
    report['same_app_account_switch_late_response_ignored'] = true;
  }
}
