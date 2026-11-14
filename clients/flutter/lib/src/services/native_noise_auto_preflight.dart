part of 'native_noise_suppression.dart';

mixin _NativeNoiseAutoPreflight on _NativeNoiseCore {
  @override
  Future<NoiseSuppressionMode> _selectAuto(int generation) async {
    if (_debugAutoMode != NoiseSuppressionMode.browser) return _debugAutoMode;
    final clock = Stopwatch()..start();
    while (!_disposed &&
        generation == _generation &&
        clock.elapsedMilliseconds < 2000) {
      try {
        final value = await _call('getNoiseSuppressionCapabilities');
        if (_disposed ||
            generation != _generation ||
            value is! Map ||
            value['rnnoiseModelId'] != 'rnnoise-stock-v0.2') {
          break;
        }
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
