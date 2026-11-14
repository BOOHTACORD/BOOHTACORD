part of 'native_noise_suppression.dart';

mixin _NativeNoiseMonitor on _NativeNoiseCore {
  void monitor(Future<void> Function(String reason) recover) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_polling ||
          _fallback ||
          (_selectedMode != NoiseSuppressionMode.rnnoise &&
              _selectedMode != NoiseSuppressionMode.deepfilter)) {
        return;
      }
      _polling = true;
      final generation = _generation;
      unawaited(
        run(() async {
          if (generation != _generation || _disposed) return;
          try {
            await refresh();
            final reason = state.failureReason;
            if (reason != null &&
                reason.isNotEmpty &&
                reason != 'awaiting-audio' &&
                reason != 'awaiting-model' &&
                generation == _generation) {
              await recover(reason);
            }
          } catch (_) {
            if (generation == _generation) await recover('hook-error');
          }
        }).catchError((Object _) {}).whenComplete(() => _polling = false),
      );
    });
  }
}
