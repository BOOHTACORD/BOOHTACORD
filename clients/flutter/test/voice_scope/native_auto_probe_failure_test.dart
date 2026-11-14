import 'package:flutter_test/flutter_test.dart';

import '../../../../tools/qa/native_audio_auto/failure_latch.dart';

void main() {
  test('the first terminal failure survives later successful recovery', () {
    final latch = FailureLatch();
    for (final value in [null, '', 'awaiting-model', 'awaiting-audio']) {
      latch.observe(value);
      expect(latch.reason, isNull);
    }
    latch.observe('processor-underrun');
    latch.observe('');
    latch.observe('processor-failed');
    expect(latch.reason, 'processor-underrun');
  });
  test('diagnostics never retain arbitrary channel error text', () {
    final latch = FailureLatch()..observe('synthetic-private-error-value');
    expect(latch.reason, 'other-native-failure');
  });
}
