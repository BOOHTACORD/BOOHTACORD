part of '../../workspace_screen_test.dart';

Future<void> _verifyScreenAndJoining(
  WidgetTester tester,
  _PublishedScreenState state,
) async {
  expect(find.byTooltip('Начать демонстрацию экрана'), findsNWidgets(2));
  final startScreenShareSemantics = tester.getSemantics(
    find.byTooltip('Начать демонстрацию экрана').first,
  );
  expect(startScreenShareSemantics.label, 'Начать демонстрацию экрана');
  expect(
    startScreenShareSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
    isTrue,
  );
  await tester.tap(find.byTooltip('Начать демонстрацию экрана').first);
  await tester.pump();
  expect(find.text('Демонстрация экрана'), findsOneWidget);
  expect(find.text('Качество трансляции'), findsOneWidget);
  await tester.tap(find.text('Отмена'));
  await tester.pumpAndSettle();

  state.voicePhase = VoicePhase.joining;
  state.notifyListeners();
  await tester.pump();
  expect(find.text('Подключено'), findsNothing);
  expect(find.text('Подключаемся к голосовому каналу'), findsOneWidget);
  expect(find.text('Соединяемся с голосовой комнатой.'), findsNothing);
  final dockShareAction = find.descendant(
    of: find.byTooltip('Начать демонстрацию экрана').first,
    matching: find.byType(InkWell),
  );
  expect(tester.widget<InkWell>(dockShareAction).onTap, isNull);

  state.deafenChanging = true;
  state.notifyListeners();
  await tester.pump();
  final deafenButton = find.descendant(
    of: find.byTooltip('Выключить удалённый звук'),
    matching: find.byType(InkWell),
  );
  expect(tester.widget<InkWell>(deafenButton).onTap, isNull);
}
