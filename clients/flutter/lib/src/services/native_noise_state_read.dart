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
        _selectedMode == NoiseSuppressionMode.rnnoise ||
        _selectedMode == NoiseSuppressionMode.deepfilter;
    final active =
        effective == _selectedMode.name &&
        frames > 0 &&
        (reason == null || reason.isEmpty);
    _update(
      NativeNoiseSuppressionState(
        requestedMode: state.requestedMode,
        effectiveMode: nativeMode
            ? active
                  ? _selectedMode.name
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
