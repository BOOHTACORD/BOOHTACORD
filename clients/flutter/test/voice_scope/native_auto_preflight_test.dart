import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const eligible = {
    'rnnoiseModelId': 'rnnoise-stock-v0.2',
    'rnnoisePreflightState': 2,
    'rnnoiseP95Us': 200,
    'rnnoiseMaxUs': 400,
  };
  test(
    'Auto selects the measured v0.2 backend without a research override',
    () async {
      final engines = <String>[];
      final native = NativeNoiseSuppression(
        invoke: (method, args) async {
          if (method == 'getNoiseSuppressionCapabilities') return eligible;
          if (method == 'setNoiseSuppressionEngine') {
            engines.add(args!['engine'] as String);
          }
          return {
            'supported': true,
            'effectiveEngine': 'rnnoise',
            'processedFrames': 1,
          };
        },
      );
      addTearDown(native.dispose);
      expect(
        await native.prepare(NoiseSuppressionMode.auto),
        NoiseSuppressionMode.rnnoise,
      );
      expect(engines, ['rnnoise']);
      expect(native.state.requestedMode, NoiseSuppressionMode.auto);
      expect(native.state.effectiveMode, 'rnnoise');
    },
  );
  for (final bad in [
    {...eligible, 'rnnoiseModelId': 'rnnoise-stock-v0.1'},
    {...eligible, 'rnnoisePreflightState': 3},
    {...eligible, 'rnnoiseP95Us': 3001},
    {...eligible, 'rnnoiseMaxUs': 8001},
    {...eligible, 'rnnoiseMaxUs': 10},
    {...eligible, 'rnnoiseP95Us': double.nan},
  ]) {
    test('Auto refuses ineligible capability $bad', () async {
      final native = NativeNoiseSuppression(
        invoke: (method, args) async =>
            method == 'getNoiseSuppressionCapabilities'
            ? bad
            : {'effectiveEngine': 'browser'},
      );
      addTearDown(native.dispose);
      expect(
        await native.prepare(NoiseSuppressionMode.auto),
        NoiseSuppressionMode.browser,
      );
    });
  }
}
