import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import '../r1_native/harness.dart';

extension R2Cases on R2Harness {
  Future<void> faults() async {
    final rows = <Map<String, dynamic>>[];
    for (final mode in [
      'upgrade-error',
      'upgrade-stall',
      'ready-stall',
      'split-budget',
      'session-stall',
      'session-late401',
    ]) {
      final session = mode.startsWith('session');
      final identity = h.app.user!.accountId, room = h.app.room;
      final cookie = await h.real(h.api.transport.session.readCookie);
      final previous = h.app.realtime.socket;
      await arm(mode);
      final elapsed = Stopwatch()..start();
      if (session) {
        await h.real(() => previous!.close());
      } else {
        await reconnect();
      }
      await entered();
      if (mode == 'ready-stall' || mode == 'session-stall') {
        await h.capture(
          mode == 'ready-stall' ? 'ready-stalled' : 'session-stalled',
        );
      }
      await h.wait(() => h.app.realtime.socket != previous && h.fresh);
      final ms = elapsed.elapsedMilliseconds;
      if (mode != 'upgrade-error') {
        expect(ms, greaterThanOrEqualTo(session ? 9000 : 14000));
        expect(ms, lessThan(session ? 18000 : 23000));
      } else {
        expect(ms, lessThan(10000));
      }
      if (mode == 'session-late401') {
        await h.real(() => Future<void>.delayed(const Duration(seconds: 3)));
      }
      expect(h.app.user?.accountId == identity, isTrue);
      expect(identical(h.app.room, room), isTrue);
      expect(
        (await h.real(h.api.transport.session.readCookie)) == cookie,
        isTrue,
      );
      await healthy();
      final observed = await stats();
      if (mode == 'session-late401') expect(observed['response_status'], 401);
      if (mode != 'upgrade-error') expect(observed['cancelled'], isTrue);
      rows.add({
        ...observed,
        'recovered_ms': ms,
        'identity_cookie_media_preserved': true,
      });
    }
    h.report['r2_faults'] = rows;
  }
}
