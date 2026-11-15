import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/widgets/noise_suppression_settings.dart';

void main() {
  Future<void> show(WidgetTester tester, String model) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NoiseSuppressionSettings(
              processing: const AudioProcessingPreferences(
                noiseSuppressionMode: NoiseSuppressionMode.rnnoise,
              ),
              runtime: NativeNoiseSuppressionState(
                requestedMode: NoiseSuppressionMode.rnnoise,
                effectiveMode: 'rnnoise',
                status: 'active',
                processedFrames: 10,
                rnnoiseModelId: model,
              ),
              onChanged: (_) async {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('ordinary Windows settings expose both versioned engines', (
    tester,
  ) async {
    await show(tester, 'rnnoise-release-v0.2');
    expect(find.text('RNNoise 0.2'), findsWidgets);
    await tester.tap(
      find.byType(DropdownButtonFormField<NoiseSuppressionMode>),
    );
    await tester.pumpAndSettle();
    expect(find.text('DeepFilterNet3'), findsWidgets);
    expect(find.textContaining('экспериментальное'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('details report the native model instead of an invented v0.1', (
    tester,
  ) async {
    await show(tester, 'rnnoise-release-v0.2');
    await tester.tap(find.text('Сведения об обработке'));
    await tester.pumpAndSettle();
    expect(find.textContaining('rnnoise-release-v0.2'), findsOneWidget);
    expect(find.textContaining('rnnoise-stock-v0.1'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('an older native model is identified honestly', (tester) async {
    await show(tester, 'rnnoise-stock-v0.1');
    expect(find.text('RNNoise 0.1'), findsWidgets);
    expect(find.text('RNNoise 0.2'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  test('native state retains reported model identity', () async {
    final service = NativeNoiseSuppression(
      invoke: (method, arguments) async => {
        'supported': true,
        'effectiveEngine': 'rnnoise',
        'processedFrames': 12,
        'rnnoiseModelId': 'rnnoise-release-v0.2',
        'deepfilterModelId': 'deepfilternet3-research-d375b2d',
      },
    );
    await service.prepare(NoiseSuppressionMode.rnnoise);
    expect(service.state.rnnoiseModelId, 'rnnoise-release-v0.2');
    expect(service.state.deepfilterModelId, 'deepfilternet3-research-d375b2d');
    service.dispose();
  });

  test('manual neural selection allows bounded cold factory startup', () async {
    final service = NativeNoiseSuppression(
      invoke: (method, arguments) async {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        return {
          'supported': true,
          'effectiveEngine': 'unknown',
          'processedFrames': 0,
          'failureReason': 'awaiting-audio',
          'rnnoiseModelId': 'rnnoise-release-v0.2',
        };
      },
    );
    expect(
      await service.prepare(NoiseSuppressionMode.rnnoise),
      NoiseSuppressionMode.rnnoise,
    );
    expect(service.state.status, 'initializing');
    service.dispose();
  });
}
