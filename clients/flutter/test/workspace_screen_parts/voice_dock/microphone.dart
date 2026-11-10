part of '../../workspace_screen_test.dart';

Future<void> _verifyMicrophoneModes(
  WidgetTester tester,
  _PublishedScreenState state,
) async {
  final microphoneButton = tester.getSemantics(
    find.bySemanticsLabel('Выключить микрофон').first,
  );
  expect(microphoneButton.label, 'Выключить микрофон');
  expect(microphoneButton.flagsCollection.isToggled, Tristate.isTrue);
  state.microphoneUnavailable = true;
  state.notifyListeners();
  await tester.pump();
  final unavailableMicrophoneButton = tester.getSemantics(
    find.byTooltip('Микрофон недоступен · повторить включение'),
  );
  expect(
    unavailableMicrophoneButton.label,
    'Повторить включение микрофона — микрофон недоступен',
  );
  expect(
    unavailableMicrophoneButton.getSemanticsData().hasAction(
      SemanticsAction.tap,
    ),
    isTrue,
  );
  state.microphoneUnavailable = false;
  state.audioActivationMode = AudioActivationMode.ptt;
  state.notifyListeners();
  await tester.pump();
  final pushToTalkMicrophoneButton = tester.getSemantics(
    find.byTooltip('Микрофон управляется push-to-talk'),
  );
  expect(pushToTalkMicrophoneButton.label, 'Микрофон управляется push-to-talk');
  expect(
    pushToTalkMicrophoneButton.getSemanticsData().hasAction(
      SemanticsAction.tap,
    ),
    isFalse,
  );
  state.audioActivationMode = AudioActivationMode.vad;
  state.notifyListeners();
  await tester.pump();
  final deafenSemantics = tester.getSemantics(
    find.byTooltip('Выключить удалённый звук'),
  );
  expect(deafenSemantics.label, 'Выключить удалённый звук');
  expect(deafenSemantics.flagsCollection.isToggled, Tristate.isFalse);
}
