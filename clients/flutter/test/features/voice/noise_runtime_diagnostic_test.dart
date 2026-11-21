import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/noise_runtime_diagnostic.dart';

void main() {
  test(
    'diagnostics identify a bounded runtime failure without raw details',
    () {
      const state = NativeNoiseSuppressionState(
        requestedMode: NoiseSuppressionMode.rnnoise,
        effectiveMode: 'unknown',
        status: 'error',
        failureReason: 'browser-recovery-failed',
        processedFrames: 7,
        fallbackFrames: 2,
        sampleRate: 48000,
        channels: 1,
      );
      expect(
        noiseRuntimeDiagnostic(state),
        contains('browser-recovery-failed'),
      );
      expect(noiseRuntimeDiagnostic(state), contains('processed=7'));
      expect(noiseRuntimeDiagnostic(state), contains('rate=48000'));
    },
  );

  test('diagnostics do not expose unexpected native text', () {
    const state = NativeNoiseSuppressionState(
      effectiveMode: 'sensitive-engine-detail',
      status: 'sensitive-status-detail',
      failureReason: 'sensitive-native-detail',
    );
    final output = noiseRuntimeDiagnostic(state);
    expect(output, isNot(contains('sensitive')));
    expect(output, contains('reason=other'));
  });
}
