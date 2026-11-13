part of 'guest.dart';

extension _GuestConnection on MaintenanceGuestSocket {
  bool _current(int epoch) => _running && epoch == _epoch;

  void _beginConnect() {
    final opening = _connect();
    _openings.add(opening);
    unawaited(
      opening.then((_) {
        _openings.remove(opening);
      }),
    );
  }

  Future<void> _drainOpenings() async {
    while (_openings.isNotEmpty) {
      await Future.wait(_openings.toList()).timeout(const Duration(seconds: 5));
    }
  }

  Future<void> _connect() async {
    if (!_running || _connecting || _socket != null) return;
    _connecting = true;
    _ready = false;
    final epoch = ++_epoch;
    _token = state.begin();
    _timeout = schedule(initialTimeout, () => _fail(epoch));
    try {
      final opened = await open();
      if (!_current(epoch)) {
        await opened.close();
        return;
      }
      _connecting = false;
      _socket = opened;
      _liveness = RealtimeLiveness(
        opened.protocol == heartbeatProtocol,
        () => _fail(epoch),
      );
      _subscription = opened.listen(
        (raw) => _receive(epoch, raw),
        onDone: () => _fail(epoch),
        onError: (Object _) => _fail(epoch),
        cancelOnError: true,
      );
    } catch (_) {
      _fail(epoch);
    }
  }

  void _fail(int epoch) {
    if (!_current(epoch)) return;
    _epoch++;
    if (_connecting) abortOpen?.call();
    _connecting = false;
    _ready = false;
    _liveness?.stop();
    _liveness = null;
    _timeout?.cancel();
    _timeout = null;
    final token = _token;
    _token = null;
    if (token != null) state.end(token);
    _scheduleRetry(_closeActive());
  }

  void _scheduleRetry(Future<void> closing) {
    if (!_running) return;
    final ceiling = min(30000, 1000 * (1 << _attempt.clamp(0, 5)));
    _attempt = (_attempt + 1).clamp(0, 30);
    final delay = Duration(
      milliseconds: (ceiling * (.5 + .5 * jitter().clamp(0, 1))).round(),
    );
    _retry = schedule(delay, () async {
      _retry = null;
      await closing;
      try {
        await _drainOpenings();
      } catch (_) {
        if (_running) _scheduleRetry(Future<void>.value());
        return;
      }
      if (_running) _beginConnect();
    });
  }

  Future<void> _closeActive() {
    final subscription = _subscription, socket = _socket;
    _subscription = null;
    _socket = null;
    final previous = _closing;
    final next = () async {
      await previous;
      try {
        await subscription?.cancel();
      } finally {
        await socket?.close();
      }
    }();
    _closing = next.catchError((Object _) {});
    return _closing;
  }
}
