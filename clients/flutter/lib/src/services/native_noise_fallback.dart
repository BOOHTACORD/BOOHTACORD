part of 'native_noise_suppression.dart';

mixin _NativeNoiseFallback on _NativeNoiseCore {
  Future<void> useFallback(
    String reason, {
    bool unsupported = false,
    bool captureApplied = true,
  }) async {
    final requested = state.requestedMode;
    final generation = _generation;
    _fallback = true;
    try {
      await _call('setNoiseSuppressionEngine', {'engine': 'browser'});
    } catch (_) {}
    if (generation != _generation || _disposed) return;
    _update(
      NativeNoiseSuppressionState(
        requestedMode: requested,
        effectiveMode: captureApplied ? 'browser' : 'unknown',
        status: captureApplied
            ? unsupported
                  ? 'unsupported'
                  : 'fallback'
            : 'initializing',
        failureReason: reason,
      ),
    );
  }

  void confirmFallback(String reason, {bool unsupported = false}) {
    _update(
      NativeNoiseSuppressionState(
        requestedMode: state.requestedMode,
        effectiveMode: 'browser',
        status: unsupported ? 'unsupported' : 'fallback',
        failureReason: reason,
      ),
    );
  }

  Future<void> reset() async {
    try {
      await _call('resetNoiseSuppression');
    } catch (_) {}
  }

  void failMuted(String reason) {
    _generation++;
    _timer?.cancel();
    _fallback = true;
    _update(
      NativeNoiseSuppressionState(
        requestedMode: state.requestedMode,
        status: 'error',
        failureReason: reason,
      ),
    );
  }
}
