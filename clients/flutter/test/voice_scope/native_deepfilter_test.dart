import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'waits for the model but does not claim audio before first frame',
    () async {
      var polls = 0;
      final native = NativeNoiseSuppression(
        allowExperimentalDeepFilter: true,
        invoke: (method, args) async {
          if (method == 'setNoiseSuppressionEngine') {
            expect(args?['engine'], 'deepfilter');
            return {
              'supported': true,
              'effectiveEngine': 'unknown',
              'failureReason': 'awaiting-model',
            };
          }
          polls++;
          return {
            'supported': true,
            'effectiveEngine': 'unknown',
            'failureReason': polls < 2 ? 'awaiting-model' : 'awaiting-audio',
          };
        },
      );
      addTearDown(native.dispose);
      expect(
        await native.prepare(NoiseSuppressionMode.deepfilter),
        NoiseSuppressionMode.deepfilter,
      );
      expect(polls, 2);
      expect(native.state.status, 'initializing');
      expect(native.state.effectiveMode, 'unknown');
      expect(
        const AudioProcessingPreferences(
          noiseSuppressionMode: NoiseSuppressionMode.deepfilter,
        ).noiseSuppression,
        false,
      );
    },
  );

  test(
    'unavailable or failed model falls back while retaining requested mode',
    () async {
      final native = NativeNoiseSuppression(
        allowExperimentalDeepFilter: true,
        invoke: (method, args) async => {
          'supported': true,
          'effectiveEngine': 'unknown',
          'failureReason': 'processor-failed',
        },
      );
      addTearDown(native.dispose);
      expect(
        await native.prepare(NoiseSuppressionMode.deepfilter),
        NoiseSuppressionMode.browser,
      );
      expect(native.state.requestedMode, NoiseSuppressionMode.deepfilter);
      expect(native.state.failureReason, 'processor-failed');
    },
  );

  test('already processed native frames establish active engine', () async {
    final native = NativeNoiseSuppression(
      allowExperimentalDeepFilter: true,
      invoke: (method, args) async => {
        'supported': true,
        'effectiveEngine': 'deepfilter',
        'processedFrames': 3,
        'failureReason': '',
      },
    );
    addTearDown(native.dispose);
    expect(
      await native.prepare(NoiseSuppressionMode.deepfilter),
      NoiseSuppressionMode.deepfilter,
    );
    expect(native.state.effectiveMode, 'deepfilter');
    expect(native.state.status, 'active');
  });

  test(
    'disabled build preserves preference and never starts the engine',
    () async {
      var calls = 0;
      final native = NativeNoiseSuppression(
        allowExperimentalDeepFilter: false,
        invoke: (method, args) async {
          calls++;
          return {'supported': true};
        },
      );
      addTearDown(native.dispose);
      expect(
        await native.prepare(NoiseSuppressionMode.deepfilter),
        NoiseSuppressionMode.browser,
      );
      expect(native.state.requestedMode, NoiseSuppressionMode.deepfilter);
      expect(native.state.status, 'unsupported');
      expect(calls, 0);
    },
  );
}
