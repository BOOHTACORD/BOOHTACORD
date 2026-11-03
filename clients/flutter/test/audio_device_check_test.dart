import 'dart:async';

import 'package:boohtacord_desktop/src/services/audio_device_check.dart';
import 'package:boohtacord_desktop/src/widgets/audio_device_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolves the selected microphone by ID, then exact label', () {
    const selected = InputDevice(id: 'usb-1', label: 'USB Microphone');
    const available = [
      InputDevice(id: 'built-in', label: 'Built-in Microphone'),
      selected,
    ];

    expect(
      resolveInputDevice(
        selectedId: 'usb-1',
        selectedLabel: 'USB Microphone',
        available: available,
      ),
      selected,
    );
    expect(
      resolveInputDevice(
        selectedId: 'changed-id',
        selectedLabel: ' USB MICROPHONE ',
        available: available,
      ),
      selected,
    );
    const builtIn = InputDevice(id: '6', label: 'Built-in Microphone');
    expect(
      resolveInputDevice(
        selectedId: 'microphone-bottom',
        selectedLabel: 'Built-in Microphone (bottom)',
        available: const [builtIn],
        recorderDeviceId: '6',
      ),
      builtIn,
    );
    expect(
      resolveInputDevice(
        selectedId: 'microphone-bottom',
        selectedLabel: 'Built-in Microphone (bottom)',
        available: const [builtIn],
      ),
      builtIn,
    );
    expect(
      resolveInputDevice(
        selectedId: 'default',
        selectedLabel: null,
        available: available,
      ),
      isNull,
    );
    expect(
      () => resolveInputDevice(
        selectedId: 'missing',
        selectedLabel: 'Missing Microphone',
        available: available,
      ),
      throwsA(isA<AudioDeviceCheckFailure>()),
    );
  });

  test('maps microphone dBFS samples to a bounded linear meter', () {
    expect(amplitudePercentFromDb(double.negativeInfinity), 0);
    expect(amplitudePercentFromDb(-100), 0);
    expect(amplitudePercentFromDb(-20), closeTo(0.1, 0.001));
    expect(amplitudePercentFromDb(0), 1);
    expect(amplitudePercentFromDb(10), 1);
  });

  test('keeps Android communication output on its AudioManager route', () {
    expect(
      resolvePlaybackDevice(
        selectedId: 'android-communication-route:21',
        selectedLabel: 'Динамик телефона',
        available: const [],
      ),
      isNull,
    );
    expect(
      resolvePlaybackDevice(
        selectedId: 'android-usb-route:21',
        selectedLabel: 'USB headset',
        available: const [],
      ),
      isNull,
    );
  });

  testWidgets('checks the microphone level and selected output locally', (
    tester,
  ) async {
    final service = _FakeAudioDeviceCheckService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioDeviceCheck(
            inputDeviceId: 'input-1',
            inputDeviceLabel: 'USB microphone',
            outputDeviceId: 'output-1',
            outputDeviceLabel: 'USB speakers',
            serviceFactory: () => service,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Проверить микрофон'));
    await tester.pumpAndSettle();
    expect(service.startedInputId, 'input-1');
    expect(service.startedInputLabel, 'USB microphone');
    expect(
      find.text('Говорите, чтобы увидеть уровень микрофона.'),
      findsOneWidget,
    );

    service.levels.add(0.42);
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.42,
    );

    await tester.tap(find.text('Остановить проверку микрофона'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Говорите, чтобы увидеть уровень микрофона.'),
      findsNothing,
    );
    expect(service.stopCount, 1);

    await tester.tap(find.text('Тестовый звук'));
    await tester.pumpAndSettle();
    expect(service.playedOutputId, 'output-1');
    expect(service.playedOutputLabel, 'USB speakers');
    expect(find.textContaining('Сигнал воспроизведён.'), findsOneWidget);
    expect(find.textContaining('Проверка локальная'), findsNothing);
    await tester.tap(find.text('О проверке устройств'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Проверка локальная'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(service.disposeCount, 1);
  });

  testWidgets('clears speaker feedback when the selected output changes', (
    tester,
  ) async {
    final service = _FakeAudioDeviceCheckService();
    Widget buildCheck(String outputId, String outputLabel) => MaterialApp(
      home: Scaffold(
        body: AudioDeviceCheck(
          inputDeviceId: null,
          inputDeviceLabel: null,
          outputDeviceId: outputId,
          outputDeviceLabel: outputLabel,
          serviceFactory: () => service,
        ),
      ),
    );

    await tester.pumpWidget(buildCheck('output-1', 'USB speakers'));
    await tester.tap(find.text('Тестовый звук'));
    await tester.pumpAndSettle();
    expect(service.playedOutputId, 'output-1');
    expect(find.textContaining('Сигнал воспроизведён.'), findsOneWidget);

    await tester.pumpWidget(buildCheck('output-2', 'Monitor audio'));
    expect(find.textContaining('Сигнал воспроизведён.'), findsNothing);

    await tester.tap(find.text('Тестовый звук'));
    await tester.pumpAndSettle();
    expect(service.playedOutputId, 'output-2');
    expect(find.textContaining('Сигнал воспроизведён.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ignores an in-flight speaker result after output changes', (
    tester,
  ) async {
    final service = _FakeAudioDeviceCheckService();
    final playbackGate = Completer<void>();
    service.playbackGate = playbackGate;
    Widget buildCheck(String outputId) => MaterialApp(
      home: Scaffold(
        body: AudioDeviceCheck(
          inputDeviceId: null,
          inputDeviceLabel: null,
          outputDeviceId: outputId,
          outputDeviceLabel: outputId,
          serviceFactory: () => service,
        ),
      ),
    );

    await tester.pumpWidget(buildCheck('output-1'));
    await tester.tap(find.text('Тестовый звук'));
    await tester.pump();
    expect(find.text('Воспроизводим короткий сигнал…'), findsOneWidget);

    await tester.pumpWidget(buildCheck('output-2'));
    expect(find.text('Воспроизводим короткий сигнал…'), findsNothing);
    playbackGate.complete();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Сигнал воспроизведён.'), findsNothing);
    expect(find.text('Тестовый звук'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'stops an active microphone check when its selected device changes',
    (tester) async {
      final service = _FakeAudioDeviceCheckService();
      Widget buildCheck(String inputId) => MaterialApp(
        home: Scaffold(
          body: AudioDeviceCheck(
            inputDeviceId: inputId,
            inputDeviceLabel: inputId,
            outputDeviceId: null,
            outputDeviceLabel: null,
            serviceFactory: () => service,
          ),
        ),
      );

      await tester.pumpWidget(buildCheck('input-1'));
      await tester.tap(find.text('Проверить микрофон'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildCheck('input-2'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Говорите, чтобы увидеть уровень микрофона.'),
        findsNothing,
      );
      expect(service.stopCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('reports when the microphone level stream ends unexpectedly', (
    tester,
  ) async {
    final service = _FakeAudioDeviceCheckService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioDeviceCheck(
            inputDeviceId: 'input-1',
            inputDeviceLabel: 'USB microphone',
            outputDeviceId: null,
            outputDeviceLabel: null,
            serviceFactory: () => service,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Проверить микрофон'));
    await tester.pumpAndSettle();
    await service.levels.close();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Не удалось проверить микрофон. Проверьте разрешение и выбранное устройство.',
      ),
      findsOneWidget,
    );
    expect(find.text('Проверить микрофон'), findsOneWidget);
    expect(service.stopCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeAudioDeviceCheckService implements AudioDeviceCheckService {
  final StreamController<double> levels = StreamController<double>.broadcast(
    sync: true,
  );
  String? startedInputId;
  String? startedInputLabel;
  String? playedOutputId;
  String? playedOutputLabel;
  Completer<void>? playbackGate;
  int stopCount = 0;
  int disposeCount = 0;

  @override
  Future<Stream<double>> startMicrophone({
    String? deviceId,
    String? deviceLabel,
  }) async {
    startedInputId = deviceId;
    startedInputLabel = deviceLabel;
    return levels.stream;
  }

  @override
  Future<void> stopMicrophone() async {
    stopCount++;
  }

  @override
  Future<void> playSpeaker({String? deviceId, String? deviceLabel}) async {
    playedOutputId = deviceId;
    playedOutputLabel = deviceLabel;
    final gate = playbackGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await levels.close();
  }
}
