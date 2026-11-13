part of 'native_noise_suppression.dart';

mixin _NativeNoiseStateRead on _NativeNoiseCore {
  @override
  void _read(Map value) {
    final frames = value['processedFrames'] is int
        ? value['processedFrames'] as int
        : 0;
    final effective = value['effectiveEngine'];
    final reason = value['failureReason'] as String?;
    final nativeMode =
        state.requestedMode == NoiseSuppressionMode.rnnoise ||
        state.requestedMode == NoiseSuppressionMode.deepfilter;
    final active =
        effective == state.requestedMode.name &&
        frames > 0 &&
        (reason == null || reason.isEmpty);
    _update(
      NativeNoiseSuppressionState(
        requestedMode: state.requestedMode,
        effectiveMode: nativeMode
            ? active
                  ? state.requestedMode.name
                  : 'unknown'
            : effective == 'browser' || effective == 'off'
            ? effective as String
            : 'unknown',
        status: nativeMode
            ? active
                  ? 'active'
                  : 'initializing'
            : 'idle',
        failureReason: reason,
        processedFrames: frames,
        fallbackFrames: value['fallbackFrames'] is int
            ? value['fallbackFrames'] as int
            : 0,
        sampleRate: value['sampleRate'] as int?,
        channels: value['channels'] as int?,
      ),
    );
  }
}
