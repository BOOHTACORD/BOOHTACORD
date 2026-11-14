import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:boohtacord_desktop/src/services/voice_processing_platform.dart';
import 'package:boohtacord_desktop/src/widgets/noise_suppression_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('Auto survives serialization and keeps safe capture suppression', () {
    final preferences = AudioProcessingPreferences.fromJson({
      'noiseSuppressionMode': 'auto',
    });
    expect(preferences.noiseSuppressionMode, NoiseSuppressionMode.auto);
    expect(preferences.noiseSuppression, isTrue);
    expect(preferences.toJson()['noiseSuppressionMode'], 'auto');
    expect(
      const AudioProcessingPreferences().noiseSuppressionMode,
      NoiseSuppressionMode.browser,
    );
    expect(
      const AudioProcessingPreferences(noiseSuppression: false)
          .noiseSuppressionMode,
      NoiseSuppressionMode.off,
    );
  });

  test(
    'Auto remains on browser fallback if the native channel fails',
    () async {
      final native = NativeNoiseSuppression(
        invoke: (_, _) async => throw StateError('unavailable'),
      );
      expect(
        await native.prepare(NoiseSuppressionMode.auto),
        NoiseSuppressionMode.browser,
      );
      expect(native.state.requestedMode, NoiseSuppressionMode.auto);
      expect(native.state.failureReason, 'unsupported');
      native.dispose();
    },
  );
  test('Auto keeps suppression enabled on Windows and Android', () async {
    for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
      bool? effective;
      await applyVoiceProcessingForPlatform(
        platform: platform,
        current: const AudioCaptureOptions(),
        next: const AudioProcessingPreferences(
          noiseSuppressionMode: NoiseSuppressionMode.auto,
        ),
        recapture: (options) async => effective = options.noiseSuppression,
        updateRuntime: (options) async => effective = options.noiseSuppression,
      );
      expect(effective, isTrue, reason: platform.name);
    }
  });

  testWidgets('unfinished Auto is hidden for normal preferences', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoiseSuppressionSettings(
            processing: const AudioProcessingPreferences(),
            runtime: const NativeNoiseSuppressionState(),
            onChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.tap(
      find.byType(DropdownButtonFormField<NoiseSuppressionMode>),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Автоматически'), findsNothing);
  });

  testWidgets('existing Auto preference remains renderable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoiseSuppressionSettings(
            processing: const AudioProcessingPreferences(
              noiseSuppressionMode: NoiseSuppressionMode.auto,
            ),
            runtime: const NativeNoiseSuppressionState(
              requestedMode: NoiseSuppressionMode.auto,
            ),
            onChanged: (_) async {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Автоматически'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
