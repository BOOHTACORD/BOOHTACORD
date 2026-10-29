import 'package:boohtacord_desktop/src/screens/voice_screen_ended.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../uiux_2026/capture_support.dart';
import 'capture.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('pending retry remains visible at width$width text$scale', (
        tester,
      ) async {
        await loadUiuxVisualCaptureFonts();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        var retries = 0;
        const boundary = ValueKey('pending-recovery-capture');
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: guildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: VoiceScreenEndedView(
                  connecting: true,
                  recoveryExhausted: true,
                  onRecoveryRetry: () => retries++,
                  choices: const [],
                  participants: const SizedBox.shrink(),
                  onScreenSelected: (_) {},
                  onReturnToParticipants: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final retry = find.text('Повторить просмотр');
        expect(retry.hitTestable(), findsOneWidget);
        expect(
          find.textContaining('Не удалось получить демонстрацию.'),
          findsOneWidget,
        );
        expect(find.text('Подключаемся к демонстрации…'), findsNothing);
        final rect = tester.getRect(retry);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.bottom, lessThanOrEqualTo(900));
        expect(tester.takeException(), isNull);
        await capturePending(
          tester,
          find.byKey(boundary),
          'pending-${width.toInt()}-${scale.toInt()}',
        );
        await tester.tap(retry);
        expect(retries, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(
          retries,
          2,
          reason: 'The visible retry is the first keyboard action.',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('ended view never exposes retry despite stale exhausted input', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceScreenEndedView(
            recoveryExhausted: true,
            onRecoveryRetry: () => fail('Ended stream retried'),
            choices: const [],
            participants: const SizedBox.shrink(),
            onScreenSelected: (_) {},
            onReturnToParticipants: () {},
          ),
        ),
      ),
    );
    expect(find.text('Повторить просмотр'), findsNothing);
    expect(find.textContaining('Демонстрация завершена.'), findsOneWidget);
  });
}
