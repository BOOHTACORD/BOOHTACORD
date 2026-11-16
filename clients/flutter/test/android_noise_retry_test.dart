import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:boohtacord_desktop/src/widgets/noise_suppression_settings.dart';

void main() {
  testWidgets('Android can retry RNNoise after an earlier unavailable result', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    NoiseSuppressionMode? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoiseSuppressionSettings(
            processing: const AudioProcessingPreferences(
              noiseSuppressionMode: NoiseSuppressionMode.browser,
            ),
            runtime: const NativeNoiseSuppressionState(
              requestedMode: NoiseSuppressionMode.rnnoise,
              status: 'unsupported',
              failureReason: 'processor-unavailable',
            ),
            onChanged: (value) async => chosen = value.noiseSuppressionMode,
          ),
        ),
      ),
    );
    await tester.tap(
      find.byType(DropdownButtonFormField<NoiseSuppressionMode>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('RNNoise 0.1').last);
    await tester.pumpAndSettle();
    expect(chosen, NoiseSuppressionMode.rnnoise);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('other platforms retain the unsupported selection guard', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    NoiseSuppressionMode? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoiseSuppressionSettings(
            processing: const AudioProcessingPreferences(
              noiseSuppressionMode: NoiseSuppressionMode.browser,
            ),
            runtime: const NativeNoiseSuppressionState(
              requestedMode: NoiseSuppressionMode.rnnoise,
              status: 'unsupported',
            ),
            onChanged: (value) async => chosen = value.noiseSuppressionMode,
          ),
        ),
      ),
    );
    await tester.tap(
      find.byType(DropdownButtonFormField<NoiseSuppressionMode>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('RNNoise 0.1').last);
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android can retry the already selected unavailable mode', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    NoiseSuppressionMode? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoiseSuppressionSettings(
            processing: const AudioProcessingPreferences(
              noiseSuppressionMode: NoiseSuppressionMode.rnnoise,
            ),
            runtime: const NativeNoiseSuppressionState(
              requestedMode: NoiseSuppressionMode.rnnoise,
              status: 'unsupported',
            ),
            onChanged: (value) async => chosen = value.noiseSuppressionMode,
          ),
        ),
      ),
    );
    await tester.tap(
      find.byType(DropdownButtonFormField<NoiseSuppressionMode>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('RNNoise 0.1').last);
    await tester.pumpAndSettle();
    expect(chosen, NoiseSuppressionMode.rnnoise);
    debugDefaultTargetPlatformOverride = null;
  });
}
