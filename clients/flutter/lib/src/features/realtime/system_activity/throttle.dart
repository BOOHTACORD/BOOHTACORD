class ActivityThrottle {
  ActivityThrottle(this._elapsed);
  final Duration Function() _elapsed;
  Duration? _lastSent;

  bool get ready {
    final last = _lastSent;
    if (last == null) return true;
    final delta = _elapsed() - last;
    return delta.isNegative || delta >= const Duration(seconds: 10);
  }

  void sent() => _lastSent = _elapsed();
}
