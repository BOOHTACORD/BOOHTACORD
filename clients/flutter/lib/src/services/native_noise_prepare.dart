part of 'native_noise_suppression.dart';

mixin _NativeNoisePrepare on _NativeNoiseCore {
  Future<NoiseSuppressionMode> prepare(NoiseSuppressionMode mode) async {
    final generation = _generation;
    // No native model is selected automatically until identity and performance
    // preflight are available. Keep the request visible in state.
    final selected = mode == NoiseSuppressionMode.auto
        ? NoiseSuppressionMode.browser
        : mode;
    final nativeMode =
        mode == NoiseSuppressionMode.rnnoise ||
        mode == NoiseSuppressionMode.deepfilter;
    _fallback = false;
    if (mode == NoiseSuppressionMode.deepfilter && !_allowDeepFilter) {
      _update(
        NativeNoiseSuppressionState(
          requestedMode: mode,
          status: 'unsupported',
          failureReason: 'unsupported',
        ),
      );
      return NoiseSuppressionMode.browser;
    }
    _update(
      NativeNoiseSuppressionState(
        requestedMode: mode,
        status: nativeMode ? 'initializing' : 'idle',
      ),
    );
    try {
      final raw = await _call('setNoiseSuppressionEngine', {
        'engine': selected.name,
      });
      if (_disposed || generation != _generation) {
        return NoiseSuppressionMode.browser;
      }
      final value = raw is Map ? raw : const {};
      if (nativeMode && value['supported'] != true) {
        _update(
          NativeNoiseSuppressionState(
            requestedMode: mode,
            status: 'unsupported',
            failureReason: value['failureReason'] as String? ?? 'unsupported',
          ),
        );
        return NoiseSuppressionMode.browser;
      }
      _read(value);
      if (mode == NoiseSuppressionMode.deepfilter) {
        final result = await waitForNoiseModel(
          enabled: true,
          active: () => !_disposed && generation == _generation,
          poll: () async {
            final current = await _call('getNoiseSuppressionState');
            if (current is! Map) return null;
            if (!_disposed && generation == _generation) _read(current);
            if (current['effectiveEngine'] == 'deepfilter' &&
                current['processedFrames'] is int &&
                (current['processedFrames'] as int) > 0 &&
                (current['failureReason'] == null ||
                    current['failureReason'] == '')) {
              return 'active';
            }
            return current['failureReason'] as String?;
          },
        );
        if (result.status == ModelPreflightStatus.cancelled) {
          return NoiseSuppressionMode.browser;
        }
        if (result.status == ModelPreflightStatus.failed) {
          _update(
            NativeNoiseSuppressionState(
              requestedMode: mode,
              status: 'unsupported',
              failureReason: result.reason,
            ),
          );
          return NoiseSuppressionMode.browser;
        }
      }
      return selected;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _update(
          NativeNoiseSuppressionState(
            requestedMode: mode,
            status: nativeMode ? 'unsupported' : 'idle',
            failureReason: 'unsupported',
          ),
        );
      }
      return nativeMode ? NoiseSuppressionMode.browser : selected;
    }
  }

  @override
  Future<void> refresh() async {
    if (_fallback || _disposed) return;
    final generation = _generation;
    final raw = await _call('getNoiseSuppressionState');
    if (generation == _generation && raw is Map) _read(raw);
  }
}
