import 'dart:convert';
import 'dart:io';

import 'inactivity_reporter.dart';
import 'throttle.dart';

class RealtimeActivityReporter {
  final Stopwatch _clock = Stopwatch()..start();
  late final ActivityThrottle _throttle = ActivityThrottle(() => _clock.elapsed);
  final InactivityReporter _inactive = InactivityReporter();

  void reportActivity(WebSocket? socket, {required bool connected}) {
    if (!connected || socket == null || !_throttle.ready) return;
    try {
      socket.add(jsonEncode({'type': 'activity'}));
      _throttle.sent();
    } catch (_) {
      // A later confirmed activity can retry.
    }
  }

  void reportInactive(WebSocket? socket, {required bool connected}) {
    if (!connected || socket == null) return;
    _inactive.report(socket, () => socket.add(jsonEncode({'type': 'inactive'})));
  }
}
