part of '../../workspace_screen_test.dart';

Future<void> _verifyLeavingDock(
  WidgetTester tester,
  _PublishedScreenState state,
) async {
  state.voicePhase = VoicePhase.leaving;
  state.notifyListeners();
  await tester.pump();
  expect(find.text('Завершаем голосовое подключение'), findsOneWidget);
  expect(find.text('Ожидаем завершения голосовой сессии.'), findsNothing);
  expect(find.byTooltip('Выходим…'), findsOneWidget);
  final leaveButton = find.descendant(
    of: find.byTooltip('Выходим…'),
    matching: find.byType(InkWell),
  );
  expect(tester.widget<InkWell>(leaveButton).onTap, isNull);
  final leaveButtonSemantics = tester.getSemantics(find.byTooltip('Выходим…'));
  expect(leaveButtonSemantics.label, 'Выходим…');
  expect(
    leaveButtonSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
    isFalse,
  );

  state.error = 'Голосовая сессия завершилась с ошибкой';
  state.notifyListeners();
  await tester.pump();
  expect(find.text(state.error!), findsOneWidget);
  final alert = find.ancestor(
    of: find.text(state.error!),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.role == SemanticsRole.alert,
    ),
  );
  expect(
    tester.getSemantics(alert).getSemanticsData().role,
    SemanticsRole.alert,
  );
  expect(tester.takeException(), isNull);
}
