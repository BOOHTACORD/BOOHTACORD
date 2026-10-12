import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

// A native getStats future cannot be cancelled. Retain it after caller timeout
// so the next tick joins the same SDK call instead of accumulating requests.
// Cache only close-together reads; the regular collection tick runs every second.
class ScreenStatsPoller {
  static const _cacheDurationMs = 250;
  Future<List<rtc.StatsReport>>? _pending;
  List<rtc.StatsReport>? _cached;
  final _clock = Stopwatch()..start();
  int? _sampledAt;
  int _revision = 0;
  Future<List<rtc.StatsReport>> read(
    Future<List<rtc.StatsReport>> Function() request,
  ) {
    final pending = _pending;
    if (pending != null) return pending.timeout(const Duration(seconds: 2));
    if (_cached != null &&
        _sampledAt != null &&
        _clock.elapsedMilliseconds - _sampledAt! < _cacheDurationMs) {
      return Future.value(_cached);
    }
    final revision = _revision;
    final next = Future<List<rtc.StatsReport>>.sync(request);
    _pending = next;
    void complete() {
      if (identical(_pending, next)) _pending = null;
    }

    next.then(
      (rows) {
        if (revision == _revision) {
          _cached = rows;
          _sampledAt = _clock.elapsedMilliseconds;
        }
        complete();
      },
      onError: (Object _) {
        complete();
      },
    );
    return next.timeout(const Duration(seconds: 2));
  }

  void clear() {
    _revision++;
    _cached = null;
    _sampledAt = null;
  }
}

final _pollers = Expando<ScreenStatsPoller>();
ScreenStatsPoller screenStatsPoller(Object owner) =>
    _pollers[owner] ??= ScreenStatsPoller();
