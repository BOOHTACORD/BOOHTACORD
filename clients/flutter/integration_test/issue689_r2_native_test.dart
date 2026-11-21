import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'r1_native/harness.dart';
import 'r2_native/harness.dart';
import 'r2_native/cases.dart';
import 'r2_native/cancellation.dart';
import 'r2_native/guest.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native R2 bounded upgrade ready session and scope cancellation',
    (tester) async {
      late R1Harness harness;
      harness = R1Harness(
        tester,
        binding,
        beforeAuthenticate: () => R2Harness(harness).guestFaults(),
      );
      // Use exactly one mounted production AppState and its isolated peer session.
      final scenario = R2Harness(harness);
      addTearDown(() => tester.runAsync(harness.cleanup));
      await scenario.setup();
      await scenario.faults();
      await scenario.cancellation();
      harness.report['status'] = 'PASS';
      binding.reportData = harness.report;
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
