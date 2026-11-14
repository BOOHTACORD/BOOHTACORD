import 'package:flutter_test/flutter_test.dart';

import '../../../tools/qa/windows_v02_probe/capture_flags.dart';

void main() {
  test('reads independent capture settings and rejects invalid values', () {
    expect(captureFlags({}), (aec: true, agc: false));
    expect(captureFlags({'BOOHTA_PROBE_AEC': '0', 'BOOHTA_PROBE_AGC': '1'}), (
      aec: false,
      agc: true,
    ));
    expect(
      () => captureFlags({'BOOHTA_PROBE_AEC': 'invalid'}),
      throwsFormatException,
    );
  });
}
