import 'dart:async';

import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cancelling runtime backup never installs a late RNNoise engine',
    () async {
      final entered = Completer<void>(), response = Completer<Object?>();
      final engines = <String>[];
      final native = NativeNoiseSuppression(
        allowExperimentalDeepFilter: true,
        invoke: (method, args) async {
          if (method == 'getNoiseSuppressionCapabilities') {
            entered.complete();
            return response.future;
          }
          if (method == 'setNoiseSuppressionEngine') {
            engines.add(args!['engine'] as String);
          }
          return {
            'supported': true,
            'effectiveEngine': 'deepfilter',
            'processedFrames': 2,
          };
        },
      );
      addTearDown(native.dispose);
      native.debugSelectAutoEngine(NoiseSuppressionMode.deepfilter);
      expect(
        await native.prepare(NoiseSuppressionMode.auto),
        NoiseSuppressionMode.deepfilter,
      );
      final pending = native.prepareAutoBackup();
      await entered.future;
      native.cancel();
      response.complete({
        'rnnoiseModelId': 'rnnoise-stock-v0.2',
        'rnnoisePreflightState': 2,
        'rnnoiseP95Us': 200,
        'rnnoiseMaxUs': 300,
      });
      expect(await pending, NoiseSuppressionMode.browser);
      expect(engines, ['deepfilter']);
      expect(native.state.requestedMode, NoiseSuppressionMode.auto);
      expect(native.state.effectiveMode, 'unknown');
    },
  );
  test(
    'runtime backup never promotes a manually selected engine to Auto',
    () async {
      final methods = <String>[];
      final native = NativeNoiseSuppression(
        allowExperimentalDeepFilter: true,
        invoke: (method, args) async {
          methods.add(method);
          return {
            'supported': true,
            'effectiveEngine': 'deepfilter',
            'processedFrames': 2,
          };
        },
      );
      addTearDown(native.dispose);
      expect(
        await native.prepare(NoiseSuppressionMode.deepfilter),
        NoiseSuppressionMode.deepfilter,
      );
      methods.clear();
      expect(await native.prepareAutoBackup(), NoiseSuppressionMode.browser);
      expect(methods, isEmpty);
      expect(native.state.requestedMode, NoiseSuppressionMode.deepfilter);
    },
  );
}
