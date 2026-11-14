import 'package:flutter_test/flutter_test.dart';

import '../../../tools/qa/windows_v02_probe/packet_delta.dart';

void main() {
  test('ignores retired reports and counts only growth of a stable report', () {
    expect(packetGrowth({'old': 77, 'new': 2}, {'new': 30}), 28);
    expect(packetGrowth({'stream': 50}, {'stream': 3}), 0);
    expect(packetGrowth({}, {'new': 30}), 0);
  });
}
