import 'audio_preferences.dart';

/// Explicit development-only probe; capability and performance are not certified.
NoiseSuppressionMode researchAutoEngine(
  String value, {
  required bool debug,
  required bool windows,
}) {
  if (!debug || !windows) return NoiseSuppressionMode.browser;
  return switch (value) {
    'rnnoise' => NoiseSuppressionMode.rnnoise,
    'deepfilter' => NoiseSuppressionMode.deepfilter,
    _ => NoiseSuppressionMode.browser,
  };
}
