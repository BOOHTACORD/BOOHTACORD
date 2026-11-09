class RealtimeSocketAttempt {
  RealtimeSocketAttempt(this.onStart, this.onEnd);

  final void Function()? onStart;
  final void Function()? onEnd;
  int _generation = 0;
  bool _active = false;

  int begin() {
    if (_active) end();
    _active = true;
    final token = ++_generation;
    onStart?.call();
    return token;
  }

  void end([int? token]) {
    if (!_active || (token != null && token != _generation)) return;
    _active = false;
    onEnd?.call();
  }
}
