import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const capabilities = {
    'rnnoiseModelId': 'rnnoise-stock-v0.2',
    'rnnoisePreflightState': 2,
    'rnnoiseP95Us': 200,
    'rnnoiseMaxUs': 400,
    'deepfilterModelId': 'deepfilternet3-research-d375b2d',
  };
  for (final failed in [false, true]) {
    test(
      'Auto preflights DeepFilter and falls back to measured RNNoise: $failed',
      () async {
        final engines = <String>[];
        var current = 'browser';
        final native = NativeNoiseSuppression(
          allowExperimentalDeepFilter: true,
          invoke: (method, args) async {
            if (method == 'getNoiseSuppressionCapabilities') {
              return capabilities;
            }
            if (method == 'setNoiseSuppressionEngine') {
              current = args!['engine'] as String;
              engines.add(current);
            }
            return {
              'supported': true,
              'effectiveEngine': current,
              'processedFrames': failed && current == 'deepfilter' ? 0 : 1,
              'failureReason': failed && current == 'deepfilter'
                  ? 'processor-failed'
                  : '',
            };
          },
        );
        addTearDown(native.dispose);
        final expected = failed
            ? NoiseSuppressionMode.rnnoise
            : NoiseSuppressionMode.deepfilter;
        expect(await native.prepare(NoiseSuppressionMode.auto), expected);
        expect(engines, failed ? ['deepfilter', 'rnnoise'] : ['deepfilter']);
        expect(native.state.requestedMode, NoiseSuppressionMode.auto);
        expect(native.state.effectiveMode, expected.name);
      },
    );
  }
  test(
    'Auto rejects an unrecognized DeepFilter model before selecting it',
    () async {
      final engines = <String>[];
      final native = NativeNoiseSuppression(
        allowExperimentalDeepFilter: true,
        invoke: (method, args) async {
          if (method == 'getNoiseSuppressionCapabilities') {
            return {...capabilities, 'deepfilterModelId': 'unverified-model'};
          }
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
    },
  );
}
