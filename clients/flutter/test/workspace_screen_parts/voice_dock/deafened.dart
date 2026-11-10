part of '../../workspace_screen_test.dart';

Future<void> _verifyDeafenedDock(
  WidgetTester tester,
  _PublishedScreenState state,
) async {
  state.deafenChanging = false;
  state.voicePhase = VoicePhase.connected;
  state.deafened = true;
  state.microphoneMuted = true;
  state.notifyListeners();
  await tester.pump();
  final deafenedButton = tester.getSemantics(
    find.byTooltip('Включить удалённый звук'),
  );
  expect(deafenedButton.label, 'Включить удалённый звук');
  expect(deafenedButton.flagsCollection.isToggled, Tristate.isTrue);
  for (final tooltip in ['Включить микрофон', 'Включить удалённый звук']) {
    final controlMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byTooltip(tooltip),
        matching: find.byType(Material),
      ),
    );
    expect(controlMaterial.color, GcColors.dangerSolid);
    expect(
      (controlMaterial.shape! as RoundedRectangleBorder).side.color,
      GcColors.danger,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byTooltip(tooltip),
              matching: find.byType(Icon),
            ),
          )
          .color,
      GcColors.onDanger,
    );
  }
  expect(
    find.text(
      'Удалённый звук и микрофон выключены. Показ экрана этой кнопкой не отключается.',
    ),
    findsNothing,
  );
}
