import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets(
    'exhausted no-track production fallback exposes bounded recovery',
    (tester) async {
      final state = await renderPending(tester);
      expect(state.voice.remoteScreenViewerRecoveryExhausted, isTrue);
      await tester.pump(const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
      expect(
        find.text('Повторить просмотр').hitTestable(),
        findsOneWidget,
        reason: 'A published screen must offer recovery after automatic attempts are exhausted.',
      );
      expect(find.text('Подключаемся к демонстрации…'), findsNothing);
    },
  );

  testWidgets('initial pending connection keeps normal connecting state', (
    tester,
  ) async {
    await renderPending(tester, exhausted: false);
    expect(find.text('Подключаемся к демонстрации…'), findsOneWidget);
    expect(find.text('Повторить просмотр'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacement publication never inherits exhausted recovery', (
    tester,
  ) async {
    await renderPending(tester, stale: true);
    expect(find.text('Подключаемся к демонстрации…'), findsOneWidget);
    expect(find.text('Повторить просмотр'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ended publication preserves explicit ended view and return action',
    (tester) async {
      await renderPending(tester, published: false);
      expect(find.text('Подключаемся к демонстрации…'), findsNothing);
      expect(find.text('Повторить просмотр'), findsNothing);
      expect(find.text('К участникам').hitTestable(), findsOneWidget);
      expect(find.textContaining('Демонстрация завершена.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final boundary in ['participant', 'selection', 'in-flight']) {
    testWidgets('$boundary boundary never inherits exhausted retry', (
      tester,
    ) async {
      await renderPending(
        tester,
        otherParticipant: boundary == 'participant',
        selectionMoved: boundary == 'selection',
        inFlight: boundary == 'in-flight',
      );
      expect(find.text('Подключаемся к демонстрации…'), findsOneWidget);
      expect(find.text('Повторить просмотр'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
