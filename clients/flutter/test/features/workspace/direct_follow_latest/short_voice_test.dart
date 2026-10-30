import 'package:boohtacord_desktop/src/screens/workspace_screen.dart';
import 'package:boohtacord_desktop/src/services/composer_draft_memory.dart';
import 'package:boohtacord_desktop/src/services/conversation_scroll_memory.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../short_viewport/status_room.dart';
import '../short_viewport/support.dart';
import 'capture.dart';
import 'fixture.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform older-history action preserves short voice/IME controls',
      (tester) async {
        await loadTailFonts();
        SharedPreferences.setMockInitialValues({});
        ComposerDraftMemory.clear();
        ConversationScrollMemory.clear();
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 2.8125;
        tester.view.physicalSize = const Size(1080, 2340);
        addTearDown(tester.view.reset);
        final state = shortEditorState(api: ReadApi());
        addTearDown(state.dispose);
        state.realtime.connected = true;
        state.voice.room = StatusRoom();
        state.voice.voicePingMs = 6;
        state.directMessageHistory = List.generate(
          40,
          (i) => message(i, dmId: state.selectedDirectMessage!.id),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            home: WorkspaceScreen(state: state),
          ),
        );
        await tester.pumpAndSettle();
        final jump = find.byKey(const ValueKey('dm-jump-latest-action'));
        expect(jump.hitTestable(), findsOneWidget);
        final composer = find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.hintText == 'Написать сообщение…',
        );
        await tester.enterText(composer, 'Own unsent draft');
        final editor = tester.widget<TextField>(composer).controller!;
        editor.selection = const TextSelection(baseOffset: 2, extentOffset: 8);
        final before = editor.value;
        tester.view.physicalSize = const Size(2340, 1080);
        tester.view.viewPadding = const FakeViewPadding(left: 82, top: 84);
        tester.view.padding = const FakeViewPadding(left: 82, top: 84);
        tester.view.viewInsets = const FakeViewPadding(bottom: 605);
        await tester.pumpAndSettle();
        expect(
          jump,
          findsNothing,
          reason: 'A tiny history region must not expose a clipped action over the composer',
        );
        final send = find.byTooltip('Отправить личное сообщение');
        final leave = find.byTooltip('Выйти из голосового канала');
        expect(send.hitTestable(), findsOneWidget);
        expect(leave.hitTestable(), findsOneWidget);
        expect(tester.getRect(send).overlaps(tester.getRect(leave)), isFalse);
        expect(
          tester.getRect(send).bottom,
          lessThanOrEqualTo((1080 - 605) / 2.8125),
        );
        expect(editor.value, before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
