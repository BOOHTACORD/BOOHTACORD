import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/workspace_screen.dart';
import 'package:boohtacord_desktop/src/services/composer_draft_memory.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../uiux_2026/capture_support.dart';
import 'support.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform landscape IME keeps DM Send and voice Leave disjoint and visible',
      (tester) async {
        await loadUiuxVisualCaptureFonts();
        SharedPreferences.setMockInitialValues({});
        ComposerDraftMemory.clear();
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 2.8125;
        tester.view.physicalSize = const Size(2340, 1080);
        tester.view.viewPadding = const FakeViewPadding(top: 84);
        tester.view.viewInsets = const FakeViewPadding(bottom: 605);
        addTearDown(tester.view.reset);
        final state = shortEditorState();
        addTearDown(state.dispose);
        const boundary = ValueKey('short-editor-capture');
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: guildTheme(),
              home: WorkspaceScreen(state: state),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final composer = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Написать сообщение…',
        );
        await tester.enterText(composer, 'QA unsent draft');
        await tester.pump();
        final send = find.byTooltip('Отправить личное сообщение');
        final leave = find.byTooltip('Выйти из голосового канала');
        expect(send.hitTestable(), findsOneWidget);
        expect(leave.hitTestable(), findsOneWidget);
        expect(tester.getRect(send).overlaps(tester.getRect(leave)), isFalse);
        expect(
          tester.getRect(send).bottom,
          lessThanOrEqualTo((1080 - 605) / 2.8125),
        );
        expect(tester.takeException(), isNull);
        await captureUiuxBoundary(
          tester,
          find.byKey(boundary),
          fileName: 'issue582-${platform.name}-landscape-ime.png',
          pixelRatio: 2.8125,
        );
        expect(
          tester.widget<TextField>(composer).controller!.text,
          'QA unsent draft',
        );
        final controller = tester.widget<TextField>(composer).controller!;
        const selection = TextSelection(baseOffset: 3, extentOffset: 8);
        controller.selection = selection;
        for (final portrait in [false, true, false]) {
          tester.view.physicalSize = portrait
              ? const Size(1080, 2340)
              : const Size(2340, 1080);
          tester.view.viewInsets = FakeViewPadding(bottom: portrait ? 0 : 605);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(composer).controller,
            same(controller),
          );
          expect(controller.text, 'QA unsent draft');
          expect(controller.selection, selection);
          expect(send.hitTestable(), findsOneWidget);
          expect(leave.hitTestable(), findsOneWidget);
          expect(tester.getRect(send).overlaps(tester.getRect(leave)), isFalse);
          expect(tester.takeException(), isNull);
          expect(state.voiceChannel?.id, 'qa-voice');
          expect(state.voicePhase, VoicePhase.connected);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
