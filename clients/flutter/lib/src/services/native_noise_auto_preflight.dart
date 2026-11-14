part of 'native_noise_suppression.dart';

mixin _NativeNoiseAutoPreflight on _NativeNoiseCore {
  Future<NoiseSuppressionMode> prepare(NoiseSuppressionMode mode) async {
    final generation = _generation;
    final selected = mode == NoiseSuppressionMode.auto
        ? await _selectAuto(generation)
        : mode;
    if (_disposed || generation != _generation) {
      return NoiseSuppressionMode.browser;
    }
    final prepared = await _prepareSelected(mode, selected, generation);
    if (mode != NoiseSuppressionMode.auto ||
        !_allowDeepFilter ||
        selected != NoiseSuppressionMode.deepfilter ||
        prepared != NoiseSuppressionMode.browser ||
        _disposed ||
        generation != _generation) {
      return prepared;
    }
    final reason = state.failureReason;
    final backup = await _selectAuto(generation, includeDeepFilter: false);
    if (_disposed || generation != _generation) {
      return NoiseSuppressionMode.browser;
    }
    final result = await _prepareSelected(mode, backup, generation);
    if (result == NoiseSuppressionMode.browser &&
        !_disposed &&
        generation == _generation) {
      _update(
        NativeNoiseSuppressionState(
          requestedMode: mode,
          status: 'unsupported',
          failureReason: reason,
        ),
      );
    }
    return result;
  }

  Future<NoiseSuppressionMode> _selectAuto(
    int generation, {
    bool includeDeepFilter = true,
  }) async {
    if (_debugAutoMode != NoiseSuppressionMode.browser &&
        (includeDeepFilter ||
            _debugAutoMode != NoiseSuppressionMode.deepfilter)) {
      return _debugAutoMode;
    }
    final clock = Stopwatch()..start();
    while (!_disposed &&
        generation == _generation &&
        clock.elapsedMilliseconds < 2000) {
      try {
        final value = await _call('getNoiseSuppressionCapabilities');
        if (_disposed || generation != _generation || value is! Map) {
          break;
        }
        if (includeDeepFilter &&
            _allowDeepFilter &&
            value['deepfilterModelId'] == 'deepfilternet3-research-d375b2d') {
          return NoiseSuppressionMode.deepfilter;
        }
        if (value['rnnoiseModelId'] != 'rnnoise-stock-v0.2') break;
        if (value['rnnoisePreflightState'] == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
          continue;
        }
        final p95 = value['rnnoiseP95Us'], maximum = value['rnnoiseMaxUs'];
        if (value['rnnoisePreflightState'] == 2 &&
            p95 is int &&
            maximum is int &&
            p95 >= 0 &&
            p95 <= 3000 &&
            maximum >= p95 &&
            maximum <= 8000) {
          return NoiseSuppressionMode.rnnoise;
        }
      } catch (_) {
        break;
      }
      break;
    }
    return NoiseSuppressionMode.browser;
  }
}
