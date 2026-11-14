import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_auto_research.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug build define drives the Windows research selector', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const name = String.fromEnvironment('BOOHTA_RESEARCH_AUTO_ENGINE');
    final expected = researchAutoEngine(name, debug: true, windows: true);
    final native = NativeNoiseSuppression(
      allowExperimentalDeepFilter: true,
      invoke: (method, args) async => {
        'supported': true,
        'effectiveEngine': expected.name,
        'processedFrames': 3,
      },
    );
    addTearDown(native.dispose);
    expect(await native.prepare(NoiseSuppressionMode.auto), expected);
  });
  test(
    'only explicitly selected debug Windows research engines are eligible',
    () {
      for (final name in ['rnnoise', 'deepfilter']) {
        expect(researchAutoEngine(name, debug: true, windows: true).name, name);
        expect(
          researchAutoEngine(name, debug: false, windows: true),
          NoiseSuppressionMode.browser,
        );
        expect(
          researchAutoEngine(name, debug: true, windows: false),
          NoiseSuppressionMode.browser,
        );
      }
      for (final name in ['', 'auto', 'off', 'unknown']) {
        expect(
          researchAutoEngine(name, debug: true, windows: true),
          NoiseSuppressionMode.browser,
        );
      }
    },
  );
}
