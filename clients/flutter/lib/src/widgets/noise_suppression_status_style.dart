part of 'noise_suppression_settings.dart';

class _NoiseStatusStyle {
  static IconData _runtimeIcon(
    NativeNoiseSuppressionState runtime,
    NoiseSuppressionMode requestedMode,
  ) {
    if (!_NoiseStatusText._requestMatches(runtime, requestedMode)) {
      return Icons.sync;
    }
    return switch (runtime.status) {
      'active'
          when _NoiseStatusText._rnnoiseConfirmed(runtime, requestedMode) =>
        Icons.check_circle_outline,
      'initializing' => Icons.hourglass_top,
      'fallback' => Icons.swap_horiz,
      'unsupported' || 'error' => Icons.error_outline,
      'idle' => Icons.help_outline,
      _ => Icons.info_outline,
    };
  }

  static Color _runtimeColor(
    ColorScheme colors,
    NativeNoiseSuppressionState runtime,
    NoiseSuppressionMode requestedMode,
  ) {
    if (!_NoiseStatusText._requestMatches(runtime, requestedMode)) {
      return colors.onSurfaceVariant;
    }
    return switch (runtime.status) {
      'active'
          when _NoiseStatusText._rnnoiseConfirmed(runtime, requestedMode) =>
        colors.tertiary,
      'initializing' || 'fallback' => colors.primary,
      'unsupported' || 'error' => colors.error,
      _ => colors.onSurfaceVariant,
    };
  }
}
