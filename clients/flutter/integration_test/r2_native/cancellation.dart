import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';

import '../r1_native/harness.dart';
import 'harness.dart';
import 'control.dart';

extension R2Cancellation on R2Harness {
  Future<void> loginAgain() async {
    await h.real(
      () => h.app.authenticate('qa_admin', R1Harness.password, register: false),
    );
    await h.wait(() => h.fresh && h.app.phase == AppPhase.ready);
    await h.real(() => h.app.joinVoice(h.voice, listenerOnly: true));
    await healthy();
  }

  Future<void> cancellation() async {
    await arm('upgrade-stall');
    await reconnect();
    await entered();
    final elapsed = Stopwatch()..start();
    await reconnect();
    await healthy();
    expect(elapsed.elapsedMilliseconds, lessThan(5000));
    expect((await stats())['cancelled'], isTrue);
    for (final mode in ['upgrade-stall', 'session-late401']) {
      await arm(mode);
      if (mode == 'upgrade-stall') {
        await reconnect();
      } else {
        await h.real(() => h.app.realtime.socket!.close());
      }
      await entered();
      await h.real(h.app.session.logout);
      await h.wait(() => h.app.phase == AppPhase.signedOut);
      await loginAgain();
      final cookie = await h.real(h.api.transport.session.readCookie);
      if (mode == 'session-late401') {
        await h.real(() => Future<void>.delayed(const Duration(seconds: 13)));
      }
      expect(
        (await h.real(h.api.transport.session.readCookie)) == cookie,
        isTrue,
      );
      expect(h.app.phase == AppPhase.ready, isTrue);
      expect((await stats())['cancelled'], isTrue);
    }
    final currentCookie = await h.real(h.api.transport.session.readCookie);
    await h.real(() => revokeSession(currentCookie!));
    await h.wait(() => h.app.phase == AppPhase.signedOut);
    await loginAgain();
    await h.capture('recovered');
    h.report['manual_cancel_logout_late401_server_expiry'] = true;
  }
}
