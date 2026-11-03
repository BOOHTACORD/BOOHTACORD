import 'package:boohtacord_desktop/src/screens/workspace_screen.dart';
import 'package:boohtacord_desktop/src/services/composer_draft_memory.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../uiux_2026/capture_support.dart';
import 'status_capture.dart';
import 'status_room.dart';
import 'support.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final mode in ['healthy', 'recovering', 'initial']) {
      testWidgets(
        '$platform $mode measured voice status stays readable above IME',
        (tester) async {
          await loadUiuxVisualCaptureFonts();
          await (FontLoader(
            'Inter',
          )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
          SharedPreferences.setMockInitialValues({});
          ComposerDraftMemory.clear();
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          tester.view.devicePixelRatio = 2.8125;
          tester.view.physicalSize = const Size(2340, 1080);
          tester.view.viewPadding = const FakeViewPadding(left: 82, top: 84);
          tester.view.padding = const FakeViewPadding(left: 82, top: 84);
          tester.view.viewInsets = const FakeViewPadding(bottom: 605);
          addTearDown(tester.view.reset);
          final state = shortEditorState();
          addTearDown(state.dispose);
          state.voice.voicePingMs = 6;
          state.voice.room = StatusRoom();
          state.realtime.connected = mode == 'healthy';
          state.realtime.attempt = mode == 'initial' ? 0 : 1;
          const boundary = ValueKey('measured-voice-row');
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
          await captureVoiceStatus(
            tester,
            find.byKey(boundary),
            '${platform.name}-$mode',
          );
          final dock = find.byKey(const ValueKey('mobile-voice-dock'));
          const availableWidth = (2340 - 82) / 2.8125;
          expect(
            tester.getSize(dock).width,
            greaterThanOrEqualTo(
              availableWidth * (mode == 'recovering' ? .62 : .95),
            ),
            reason: 'Only a visible recovery message may reserve width; measured voice status needs room.',
          );
          final status = find.descendant(
            of: dock,
            matching: find.text('Голос подключён'),
          );
          expect(status, findsOneWidget);
          expect(tester.getSize(status).height, lessThanOrEqualTo(20));
          final room = find.descendant(
            of: dock,
            matching: find.text('SHARE_TEST · 1 участник'),
          );
          expect(room, findsOneWidget);
          expect(tester.getSize(room).height, lessThanOrEqualTo(18));
          expect(
            find.descendant(of: dock, matching: find.text('6 мс')),
            findsNothing,
          );
          expect(
            find.descendant(
              of: dock,
              matching: find.bySemanticsLabel(
                'Качество соединения: Нет данных · ping 6 мс',
              ),
            ),
            findsOneWidget,
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
          expect(
            find.byTooltip('Повторить подключение'),
            mode == 'recovering' ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
}
