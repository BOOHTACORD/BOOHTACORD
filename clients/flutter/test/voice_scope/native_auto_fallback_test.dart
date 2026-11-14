import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Auto falls back to browser and retains failure when both models fail',
    () async {
      final engines = <String>[];
      var current = 'browser';
      final native = NativeNoiseSuppression(
        allowExperimentalDeepFilter: true,
        invoke: (method, args) async {
          if (method == 'getNoiseSuppressionCapabilities') {
            return {
              'deepfilterModelId': 'deepfilternet3-research-d375b2d',
              'rnnoiseModelId': 'rnnoise-stock-v0.2',
              'rnnoisePreflightState': 3,
            };
          }
          if (method == 'setNoiseSuppressionEngine') {
            current = args!['engine'] as String;
            engines.add(current);
          }
          return {
            'supported': true,
            'effectiveEngine': current,
            'processedFrames': 0,
            'failureReason': current == 'deepfilter' ? 'processor-failed' : '',
          };
        },
      );
      addTearDown(native.dispose);
      expect(
        await native.prepare(NoiseSuppressionMode.auto),
        NoiseSuppressionMode.browser,
      );
      expect(engines, ['deepfilter', 'browser']);
      expect(native.state.requestedMode, NoiseSuppressionMode.auto);
      expect(native.state.failureReason, 'processor-failed');
      expect(native.state.status, 'unsupported');
    },
  );
}
