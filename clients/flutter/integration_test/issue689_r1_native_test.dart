import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';

import 'r1_native/harness.dart';
import 'r1_native/fixtures.dart';
import 'r1_native/replacement.dart';
import 'r1_native/history.dart';
import 'r1_native/account.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native R1 late HTTP, socket replacement, restart and account switch',
    (tester) async {
      final run = R1Harness(tester, binding);
      debugPrint('R1_NATIVE_STAGE=setup');
      await run.setup();
      addTearDown(() => tester.runAsync(run.cleanup));
      debugPrint('R1_NATIVE_STAGE=fixtures');
      await run.fixtures();
      debugPrint('R1_NATIVE_STAGE=replacement');
      await run.replacement();
      debugPrint('R1_NATIVE_STAGE=restart');
      await run.processRestart();
      debugPrint('R1_NATIVE_STAGE=history');
      await run.history();
      debugPrint('R1_NATIVE_STAGE=account');
      await run.accountSwitch();
      run.report['status'] = 'PASS';
      binding.reportData = run.report;
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
