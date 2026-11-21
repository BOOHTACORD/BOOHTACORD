import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../r1_native/harness.dart';
import 'harness.dart';

extension R2Guest on R2Harness {
  Future<void> startGuest() async {
    await h.real(h.app.maintenance.suspend);
    await h.real(() async {
      unawaited(h.app.maintenance.useGuest());
    });
  }

  Future<void> guestFaults() async {
    await h.wait(() => h.app.maintenanceKnown);
    final rows = <Map<String, dynamic>>[];
    for (final mode in [
      'public-upgrade-error',
      'public-upgrade-stall',
      'public-ready-stall',
      'public-split-budget',
    ]) {
      await arm(mode);
      final elapsed = Stopwatch()..start();
      await startGuest();
      await entered();
      if (mode != 'public-upgrade-error') {
        expect(h.app.maintenanceKnown, isFalse);
      }
      if (mode == 'public-upgrade-stall') await h.capture('public-stalled');
      await h.wait(() => h.app.maintenanceKnown);
      final ms = elapsed.elapsedMilliseconds;
      if (mode != 'public-upgrade-error') {
        expect(ms, greaterThanOrEqualTo(9000));
        expect(ms, lessThan(18000));
      }
      final sample = await stats();
      if (mode != 'public-upgrade-error') expect(sample['cancelled'], isTrue);
      rows.add({...sample, 'recovered_ms': ms});
    }
    await arm('public-upgrade-stall');
    await startGuest();
    await entered();
    await h.real(h.app.maintenance.suspend);
    expect(h.app.maintenanceKnown, isFalse);
    await h.real(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    expect((await stats())['cancelled'], isTrue);
    await h.real(h.app.maintenance.useGuest);
    await h.wait(() => h.app.maintenanceKnown);
    h.report['r2_public_faults'] = rows;
    h.report['public_scope_cancel'] = true;
  }
}
