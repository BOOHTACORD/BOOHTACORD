part of '../../workspace_screen_test.dart';

Future<void> _verifyDockPreferences(
  WidgetTester tester,
  _PublishedScreenState state,
) async {
  final soundRemote = await installDockSoundPreferences(state);
  await tester.tap(find.byTooltip('Ещё настройки голоса'));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<CheckedPopupMenuItem<String>>(
          find.widgetWithText(
            CheckedPopupMenuItem<String>,
            'Сигнал новых трансляций',
          ),
        )
        .checked,
    isTrue,
  );
  await tester.ensureVisible(find.text('Сигнал новых трансляций'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Сигнал новых трансляций'));
  await tester.pumpAndSettle();
  expect(state.voiceStreamSoundEnabled, isFalse);
  expect(soundRemote.settings['started'], isFalse);
  await tester.tap(find.byTooltip('Ещё настройки голоса'));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<CheckedPopupMenuItem<String>>(
          find.widgetWithText(
            CheckedPopupMenuItem<String>,
            'Сигнал новых трансляций',
          ),
        )
        .checked,
    isFalse,
  );
  expect(
    tester
        .widget<CheckedPopupMenuItem<String>>(
          find.widgetWithText(
            CheckedPopupMenuItem<String>,
            'Звуки входа и выхода',
          ),
        )
        .checked,
    isTrue,
  );
  await tester.ensureVisible(find.text('Звуки входа и выхода'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Звуки входа и выхода'));
  await tester.pumpAndSettle();
  expect(state.voiceRoomEventSoundsEnabled, isFalse);
  expect(soundRemote.settings['joined'], isFalse);
  state.voice.voiceRoomEventSoundsEnabled = true;
  await state.voice.loadVoiceRoomEventSoundPreference();
  expect(state.voiceRoomEventSoundsEnabled, isFalse);
  await tester.tap(find.byTooltip('Ещё настройки голоса'));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<CheckedPopupMenuItem<String>>(
          find.widgetWithText(
            CheckedPopupMenuItem<String>,
            'Звуки входа и выхода',
          ),
        )
        .checked,
    isFalse,
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}
