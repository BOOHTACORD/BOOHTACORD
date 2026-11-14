import 'dart:async';

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
    'unresponsive cold bootstrap falls back within the total deadline',
    () async {
      final engines = <String>[];
      final native = NativeNoiseSuppression(
        invoke: (method, args) async {
          if (method == 'getNoiseSuppressionCapabilities') {
            return Completer<Object?>().future;
          }
          engines.add(args!['engine'] as String);
          return {'effectiveEngine': 'browser'};
        },
      );
      addTearDown(native.dispose);
      expect(
        await native
            .prepare(NoiseSuppressionMode.auto)
            .timeout(const Duration(seconds: 3)),
        NoiseSuppressionMode.browser,
      );
      expect(engines, ['browser']);
      expect(native.state.requestedMode, NoiseSuppressionMode.auto);
    },
  );
  test('cold factory startup can exceed ordinary channel timeout within preflight deadline', () async {
    final native = NativeNoiseSuppression(
      invoke: (method, args) async {
        if (method == 'getNoiseSuppressionCapabilities') {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          return eligible;
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
  });
  test('Auto waits for the worker before setting the capture engine', () async {
    var polls = 0;
    final engines = <String>[];
    final native = NativeNoiseSuppression(
      invoke: (method, args) async {
        if (method == 'getNoiseSuppressionCapabilities') {
          polls++;
          return polls == 1
              ? {...eligible, 'rnnoisePreflightState': 1}
              : eligible;
        }
        if (method == 'setNoiseSuppressionEngine') {
          engines.add(args!['engine'] as String);
        }
        return {'supported': true};
      },
    );
    addTearDown(native.dispose);
    expect(
      await native.prepare(NoiseSuppressionMode.auto),
      NoiseSuppressionMode.rnnoise,
    );
    expect(polls, 2);
    expect(engines, ['rnnoise']);
  });
  test(
    'cancelling preflight never configures a stale capture engine',
    () async {
      final response = Completer<Object?>();
      final entered = Completer<void>();
      final engines = <String>[];
      final native = NativeNoiseSuppression(
        invoke: (method, args) async {
          if (method == 'getNoiseSuppressionCapabilities') {
            entered.complete();
            return response.future;
          }
          if (method == 'setNoiseSuppressionEngine') {
            engines.add(args!['engine'] as String);
          }
          return null;
        },
      );
      addTearDown(native.dispose);
      final pending = native.prepare(NoiseSuppressionMode.auto);
      await entered.future;
      native.cancel();
      response.complete(eligible);
      expect(await pending, NoiseSuppressionMode.browser);
      expect(engines, isEmpty);
      expect(native.state.effectiveMode, 'unknown');
    },
  );
}
