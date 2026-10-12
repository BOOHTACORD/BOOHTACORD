import 'dart:async';

import 'package:boohtacord_desktop/src/features/screen/metrics/stats_poller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

void main() {
  test(
    'joins an in-flight native request instead of starting another',
    () async {
      final poller = ScreenStatsPoller();
      final pending = Completer<List<rtc.StatsReport>>();
      var requests = 0;
      final first = poller.read(() {
        requests++;
        return pending.future;
      });
      final second = poller.read(() {
        requests++;
        return Future.value(const <rtc.StatsReport>[]);
      });

      expect(requests, 1);
      pending.complete(const []);
      expect(await first, isEmpty);
      expect(await second, isEmpty);
      expect(requests, 1);
    },
  );

  test(
    'retries after errors and expires cached rows within one tick',
    () async {
      final poller = ScreenStatsPoller();
      var requests = 0;
      await expectLater(
        poller.read(() {
          requests++;
          return Future<List<rtc.StatsReport>>.error(
            StateError('native error'),
          );
        }),
        throwsStateError,
      );
      await poller.read(() {
        requests++;
        return Future.value(const <rtc.StatsReport>[]);
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await poller.read(() {
        requests++;
        return Future.value(const <rtc.StatsReport>[]);
      });

      expect(requests, 3);
    },
  );
}
