import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:boohtacord_desktop/src/widgets/noise_suppression_settings.dart';

void main() {
  Future<void> pumpRuntime(
    WidgetTester tester,
    NativeNoiseSuppressionState runtime, {
    NoiseSuppressionMode requestedMode = NoiseSuppressionMode.rnnoise,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: NoiseSuppressionSettings(
                processing: AudioProcessingPreferences(
                  noiseSuppressionMode: requestedMode,
                ),
                runtime: runtime,
                onChanged: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('idle and initializing states do not claim the filter works', (
    tester,
  ) async {
    await pumpRuntime(
      tester,
      const NativeNoiseSuppressionState(
        requestedMode: NoiseSuppressionMode.rnnoise,
        effectiveMode: 'unknown',
        status: 'idle',
      ),
    );
    expect(
      find.byKey(const ValueKey('noise-suppression-runtime-status')),
      findsNothing,
    );
    expect(find.textContaining('Работает:'), findsNothing);

    await pumpRuntime(
      tester,
      const NativeNoiseSuppressionState(
        requestedMode: NoiseSuppressionMode.rnnoise,
        effectiveMode: 'unknown',
        status: 'initializing',
        failureReason: 'awaiting-audio',
      ),
    );
    expect(find.text('Ожидание аудиопотока'), findsOneWidget);
    expect(find.text('Ожидаем аудио от микрофона.'), findsNothing);
    expect(find.textContaining('RNNoise активен'), findsNothing);
    await tester.tap(find.text('Сведения об обработке'));
    await tester.pumpAndSettle();
    expect(find.text('Ожидаем аудио от микрофона.'), findsOneWidget);
  });

  testWidgets('active state requires a native-confirmed processed frame', (
    tester,
  ) async {
    await pumpRuntime(
      tester,
      const NativeNoiseSuppressionState(
        requestedMode: NoiseSuppressionMode.rnnoise,
        effectiveMode: 'rnnoise',
        status: 'active',
        processedFrames: 12,
      ),
    );
    expect(find.text('RNNoise активен'), findsOneWidget);
    expect(
      find.text('Нативный процессор подтвердил обработку 12 кадров.'),
      findsNothing,
    );
    await tester.tap(find.text('Сведения об обработке'));
    await tester.pumpAndSettle();
    expect(
      find.text('Нативный процессор подтвердил обработку 12 кадров.'),
      findsOneWidget,
    );

    await pumpRuntime(
      tester,
      const NativeNoiseSuppressionState(
        requestedMode: NoiseSuppressionMode.rnnoise,
        effectiveMode: 'rnnoise',
        status: 'active',
        failureReason: 'awaiting-audio',
      ),
    );
    expect(find.text('Обработка не подтверждена'), findsOneWidget);
    expect(find.text('RNNoise активен'), findsNothing);
    await tester.tap(find.text('Сведения об обработке'));
    await tester.pumpAndSettle();

    await pumpRuntime(
      tester,
      const NativeNoiseSuppressionState(
        requestedMode: NoiseSuppressionMode.rnnoise,
        effectiveMode: 'rnnoise',
        status: 'active',
        processedFrames: 12,
      ),
      requestedMode: NoiseSuppressionMode.browser,
    );
    expect(
      find.byKey(const ValueKey('noise-suppression-runtime-status')),
      findsNothing,
    );
    expect(find.text('RNNoise активен'), findsNothing);
    await tester.tap(find.text('Сведения об обработке'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Отчёт относится к предыдущему режиму; активность нового режима пока не подтверждена.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('fallback and unsupported states stay distinct', (tester) async {
    await pumpRuntime(
      tester,
      const NativeNoiseSuppressionState(
        requestedMode: NoiseSuppressionMode.rnnoise,
        effectiveMode: 'browser',
        status: 'fallback',
        failureReason: 'unsupported-audio-format',
      ),
    );
    expect(find.text('Стандартная обработка включена'), findsOneWidget);
    expect(
      find.text('Формат микрофона не поддерживается фильтром.'),
      findsNothing,
    );
    await tester.tap(find.text('Сведения об обработке'));
    await tester.pumpAndSettle();
    expect(
      find.text('Формат микрофона не поддерживается фильтром.'),
      findsOneWidget,
    );
    expect(find.textContaining('RNNoise активен'), findsNothing);

    await pumpRuntime(
      tester,
      const NativeNoiseSuppressionState(
        requestedMode: NoiseSuppressionMode.rnnoise,
        effectiveMode: 'unknown',
        status: 'unsupported',
        failureReason: 'processor-unavailable',
      ),
    );
    expect(find.text('RNNoise недоступен'), findsOneWidget);
    expect(find.textContaining('Стандартная обработка включена'), findsNothing);
  });

  testWidgets('unsupported platform does not claim fallback before capture', (
    tester,
  ) async {
    await pumpRuntime(
      tester,
      const NativeNoiseSuppressionState(
        requestedMode: NoiseSuppressionMode.rnnoise,
        effectiveMode: 'unknown',
        status: 'initializing',
        failureReason: 'platform-aec-ns-coupled',
      ),
    );

    expect(find.textContaining('связано с эхоподавлением'), findsNothing);
    expect(find.textContaining('Стандартная обработка включена'), findsNothing);
    await tester.tap(find.text('Сведения об обработке'));
    await tester.pumpAndSettle();
    expect(find.textContaining('связано с эхоподавлением'), findsOneWidget);
  });

  testWidgets('error is a live, explicit state and not an effective mode', (
    tester,
  ) async {
    await pumpRuntime(
      tester,
      const NativeNoiseSuppressionState(
        requestedMode: NoiseSuppressionMode.rnnoise,
        effectiveMode: 'unknown',
        status: 'error',
        failureReason: 'browser-recovery-failed',
      ),
    );

    expect(find.text('Обработка микрофона приостановлена'), findsOneWidget);
    expect(
      find.text('Не удалось восстановить микрофон. Отправка звука выключена.'),
      findsNothing,
    );
    final semantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('noise-suppression-runtime-status')),
    );
    expect(semantics.properties.liveRegion, isTrue);
    expect(
      semantics.properties.label,
      contains('Обработка микрофона приостановлена'),
    );
    await tester.tap(find.text('Сведения об обработке'));
    await tester.pumpAndSettle();
    expect(
      find.text('Не удалось восстановить микрофон. Отправка звука выключена.'),
      findsOneWidget,
    );
  });

  testWidgets('runtime status wraps at compact width with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: NoiseSuppressionSettings(
                processing: const AudioProcessingPreferences(
                  noiseSuppressionMode: NoiseSuppressionMode.rnnoise,
                ),
                runtime: const NativeNoiseSuppressionState(
                  requestedMode: NoiseSuppressionMode.rnnoise,
                  effectiveMode: 'unknown',
                  status: 'error',
                  failureReason: 'browser-recovery-failed',
                ),
                onChanged: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Обработка микрофона приостановлена'), findsOneWidget);
    expect(
      find.text('Не удалось восстановить микрофон. Отправка звука выключена.'),
      findsNothing,
    );
  });
}
