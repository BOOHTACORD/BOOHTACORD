class ScreenShareReportCadence {
  static const intervalMs = 5000.0;
  static const initialRetryMs = 2000.0;
  static const maxRetryMs = 30000.0;
  double? lastAttemptAtMs;
  double? lastSuccessAtMs;
  double? _nextDueAtMs;
  int _consecutiveFailures = 0;

  bool isDue(double nowMs) {
    if (!nowMs.isFinite) return false;
    final due = _nextDueAtMs;
    return due == null || nowMs >= due;
  }

  void markAttempt(double nowMs) {
    if (nowMs.isFinite) lastAttemptAtMs = nowMs;
  }

  void markSuccess(double nowMs) {
    if (!nowMs.isFinite) return;
    lastSuccessAtMs = nowMs;
    _consecutiveFailures = 0;
    _nextDueAtMs = nowMs + intervalMs;
  }

  void markFailure(double nowMs) {
    if (!nowMs.isFinite) return;
    _consecutiveFailures++;
    final shift = (_consecutiveFailures - 1).clamp(0, 20);
    final retryMs = (initialRetryMs * (1 << shift)).clamp(
      initialRetryMs,
      maxRetryMs,
    );
    _nextDueAtMs = nowMs + retryMs;
  }

  void clear() {
    lastAttemptAtMs = null;
    lastSuccessAtMs = null;
    _nextDueAtMs = null;
    _consecutiveFailures = 0;
  }
}
