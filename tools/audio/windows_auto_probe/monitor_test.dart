import 'package:flutter_test/flutter_test.dart';

import 'monitor.dart';

void main() {
  AutoSample sample(
    int frames,
    int packets, {
    int fallback = 0,
    bool active = true,
  }) =>
      (processed: frames, packets: packets, fallback: fallback, active: active);
  test('duration rejects malformed and unbounded runs', () {
    expect(probeSeconds(null), 6);
    expect(probeSeconds('1800'), 1800);
    for (final value in ['', '5', '1801', '-6', '6.0', ' 6', '６']) {
      expect(() => probeSeconds(value), throwsA(anything));
    }
  });
  test('every interval requires new processing and receiver packets', () async {
    var tick = 0;
    final waits = <int>[];
    final result = await monitorAuto(
      seconds: 12,
      read: () async => sample(100 * tick, 10 * tick++),
      pause: (duration) async {
        waits.add(duration.inSeconds);
      },
    );
    expect(waits, [5, 5, 2]);
    expect(result, containsPair('success', true));
    expect(result, containsPair('intervals', 3));
    expect(result, containsPair('minProcessedDelta', 100));
    expect(result, containsPair('minReceivedDelta', 10));
  });
  test(
    'a successful first interval cannot hide a later stall or fallback',
    () async {
      for (final last in [
        sample(100, 10),
        sample(200, 10),
        sample(200, 20, fallback: 1),
        sample(200, 20, active: false),
      ]) {
        final values = [sample(0, 0), sample(100, 10), last];
        final result = await monitorAuto(
          seconds: 15,
          read: () async => values.removeAt(0),
          pause: (_) async {},
        );
        expect(result['success'], false);
        expect(result['observedSeconds'], 10);
        expect(result['failureReason'], isNotNull);
      }
    },
  );
}
