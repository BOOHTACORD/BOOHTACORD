import 'dart:async';

/// Reports only fresh, confirmed operating-system input; null means unknown.
class SystemActivityPoller {
  SystemActivityPoller({
    required this.readIdle,
    required this.readLocked,
    required this.report,
    required this.reportInactive,
  });

  final Duration? Function() readIdle;
  final bool? Function() readLocked;
  final void Function() report;
  final void Function() reportInactive;
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      try {
        final locked = readLocked();
        if (locked == null) return;
        if (locked) {
          reportInactive();
          return;
        }
        final idle = readIdle();
        if (idle != null &&
            !idle.isNegative &&
            idle <= const Duration(seconds: 15)) {
          report();
        } else if (idle != null && !idle.isNegative) {
          reportInactive();
        }
      } catch (_) {
        // An unavailable detector is not evidence of activity.
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
