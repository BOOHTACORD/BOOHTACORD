import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final engine in [
    NoiseSuppressionMode.rnnoise,
    NoiseSuppressionMode.deepfilter,
  ]) {
    test(
      'Auto retains its request and reports active ${engine.name}',
      () async {
        final native = NativeNoiseSuppression(
          allowExperimentalDeepFilter: true,
          invoke: (method, args) async => {
            'supported': true,
            'effectiveEngine': engine.name,
            'processedFrames': 3,
            'failureReason': '',
          },
        );
        addTearDown(native.dispose);
        native.debugSelectAutoEngine(engine);
        expect(await native.prepare(NoiseSuppressionMode.auto), engine);
        expect(native.state.requestedMode, NoiseSuppressionMode.auto);
        expect(native.state.effectiveMode, engine.name);
        expect(native.state.status, 'active');
      },
    );
  }

  test('Auto monitors selected native engine and recovers a failure', () async {
    var failed = false;
    final native = NativeNoiseSuppression(
      invoke: (method, args) async => {
        'supported': true,
        'effectiveEngine': 'rnnoise',
        'processedFrames': 3,
        'failureReason': failed ? 'processor-failed' : '',
      },
    );
    addTearDown(native.dispose);
    native.debugSelectAutoEngine(NoiseSuppressionMode.rnnoise);
    await native.prepare(NoiseSuppressionMode.auto);
    final recovered = <String>[];
    native.monitor((reason) async => recovered.add(reason));
    failed = true;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(recovered, ['processor-failed']);
  });

  test(
    'Auto does not report a native engine active without processed frames',
    () async {
      final native = NativeNoiseSuppression(
        invoke: (method, args) async => {
          'supported': true,
          'effectiveEngine': 'rnnoise',
          'processedFrames': 0,
        },
      );
      addTearDown(native.dispose);
      native.debugSelectAutoEngine(NoiseSuppressionMode.rnnoise);
      expect(
        await native.prepare(NoiseSuppressionMode.auto),
        NoiseSuppressionMode.rnnoise,
      );
      expect(native.state.effectiveMode, 'unknown');
      expect(native.state.status, 'initializing');
    },
  );

  test(
    'Auto refuses DeepFilter when its research backend is unavailable',
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
      native.debugSelectAutoEngine(NoiseSuppressionMode.deepfilter);
      expect(
        await native.prepare(NoiseSuppressionMode.auto),
        NoiseSuppressionMode.browser,
      );
      expect(native.state.requestedMode, NoiseSuppressionMode.auto);
      expect(native.state.status, 'unsupported');
      expect(calls, 0);
    },
  );
}
