part of 'native_noise_suppression.dart';

mixin _NativeNoiseResearchDebug on _NativeNoiseCore {
  @visibleForTesting
  void debugSelectAutoEngine(NoiseSuppressionMode mode) {
    assert(() {
      if (mode == NoiseSuppressionMode.auto ||
          mode == NoiseSuppressionMode.off) {
        throw ArgumentError(
          'Auto research engine must be browser, rnnoise or deepfilter',
        );
      }
      _debugAutoMode = mode;
      return true;
    }());
  }
}
