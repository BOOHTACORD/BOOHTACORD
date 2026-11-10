part of '../../workspace_screen_test.dart';

Future<void> _verifyReconnectDock(
  WidgetTester tester,
  _PublishedScreenState state,
) async {
  state.voicePhase = VoicePhase.reconnecting;
  state.notifyListeners();
  await tester.pump();
  expect(find.text('Восстанавливаем голосовое соединение'), findsOneWidget);
  expect(find.text('Ручной выход отменит ожидание.'), findsNothing);
  expect(
    find.ancestor(
      of: find.text('Восстанавливаем голосовое соединение'),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    ),
    findsOneWidget,
  );
  expect(
    find.text(
      'Удалённый звук и микрофон выключены. Показ экрана этой кнопкой не отключается.',
    ),
    findsNothing,
  );
}
