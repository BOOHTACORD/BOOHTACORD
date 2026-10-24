import 'package:boohtacord_desktop/src/screens/voice_viewer_layout.dart';
import 'package:boohtacord_desktop/src/screens/voice_screen_stage.dart';
import 'package:boohtacord_desktop/src/screens/voice_screen_selection_rail.dart';
import 'package:boohtacord_desktop/src/screens/screen_fullscreen_overlay.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_viewer_participants_menu.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_viewer_streams_menu.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'uiux_2026/capture_support.dart';

void main() {
  testWidgets(
    'active screen viewer keeps the full stage and places details over it',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 640);
      addTearDown(tester.view.reset);
      final state = AppState(ApiClient());
      addTearDown(state.dispose);
      await loadUiuxVisualCaptureFonts();
      final captureKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: guildTheme().copyWith(platform: TargetPlatform.macOS),
            home: Scaffold(
              body: VoiceViewerLayout(
                stage: VoiceScreenStage(
                  video: const SizedBox.expand(
                    child: ColoredBox(
                      key: ValueKey('stream-stage'),
                      color: Colors.black,
                    ),
                  ),
                  publisherName: 'Алиса',
                  avatarName: 'Алиса',
                  bottomActions: Wrap(
                    spacing: 6,
                    children: [
                      const SizedBox(
                        key: ValueKey('viewer-audio-controls'),
                        width: 220,
                        height: 44,
                        child: ColoredBox(color: Color(0x66333A49)),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Прекратить просмотр'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {},
                        icon: const Icon(Icons.fullscreen_outlined),
                        label: const Text('Развернуть'),
                      ),
                    ],
                  ),
                ),
                diagnostics: const SizedBox(height: 24),
                streamRail: const SizedBox(
                  key: ValueKey('viewer-stream-selector'),
                  width: 180,
                  height: 44,
                ),
                participants: const SizedBox(
                  height: 92,
                  key: ValueKey('legacy-participant-footer'),
                  child: Text('Карточка участника'),
                ),
                participantsOverlay: VoiceViewerParticipantsMenu(state: state),
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Участники трансляции'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('legacy-participant-footer')),
        findsNothing,
      );
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('screen-viewer-action-hit-test')),
            )
            .ignoring,
        isTrue,
      );
      await tester.sendEventToBinding(
        const PointerHoverEvent(position: Offset(450, 320)),
      );
      await tester.pump();
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('screen-viewer-action-hit-test')),
            )
            .ignoring,
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 220));
      final stage = tester.getRect(find.byKey(const ValueKey('stream-stage')));
      expect(stage, const Rect.fromLTWH(0, 0, 900, 640));
      for (final key in const [
        ValueKey('viewer-audio-controls'),
        ValueKey('voice-screen-stage-toolbar'),
      ]) {
        final overlay = tester.getRect(find.byKey(key));
        expect(overlay.left, greaterThanOrEqualTo(stage.left));
        expect(overlay.top, greaterThanOrEqualTo(stage.top));
        expect(overlay.right, lessThanOrEqualTo(stage.right));
        expect(overlay.bottom, lessThanOrEqualTo(stage.bottom));
      }
      await captureUiuxBoundary(
        tester,
        find.byKey(captureKey),
        fileName: 'voice-viewer-participants-room.png',
        pixelRatio: 1,
      );

      await tester.tap(find.byTooltip('Участники трансляции'));
      await tester.pumpAndSettle();
      expect(find.text('Участники'), findsOneWidget);
      expect(find.byTooltip('Закрыть панель участников'), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey('stream-stage'))), stage);
      await captureUiuxBoundary(
        tester,
        find.byKey(captureKey),
        fileName: 'voice-viewer-participants-room-open.png',
        pixelRatio: 1,
      );

      await tester.tap(find.byTooltip('Закрыть панель участников'));
      await tester.pumpAndSettle();
      expect(find.text('Участники'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          home: VoiceViewerLayout(
            stage: const SizedBox.expand(),
            diagnostics: const SizedBox.shrink(),
            participants: const SizedBox(
              key: ValueKey('ended-view-participant-footer'),
              height: 92,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('ended-view-participant-footer')),
        findsOneWidget,
      );
    },
  );

  testWidgets('screen choices open on demand over the full-stage viewer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 640);
    addTearDown(tester.view.reset);
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: Scaffold(
          body: VoiceViewerLayout(
            stage: const SizedBox.expand(
              child: ColoredBox(
                key: ValueKey('multi-stream-stage'),
                color: Colors.black,
              ),
            ),
            diagnostics: const SizedBox.shrink(),
            streamRail: VoiceViewerStreamsMenu(
              choices: const [
                VoiceScreenChoice(
                  identity: 'peer-1',
                  label: 'Алиса',
                  selected: true,
                ),
                VoiceScreenChoice(
                  identity: 'peer-2',
                  label: 'Борис',
                  selected: false,
                ),
              ],
              onSelected: (identity) => selected = identity,
            ),
            participants: const SizedBox.shrink(),
            participantsOverlay: const SizedBox(
              key: ValueKey('participants-menu-trigger'),
              width: 180,
              height: 44,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Трансляции · 2'), findsOneWidget);
    expect(find.text('Экран Борис'), findsNothing);
    await tester.tap(find.text('Трансляции · 2'));
    await tester.pumpAndSettle();
    expect(find.text('Экран Борис'), findsOneWidget);
    await tester.tap(find.text('Экран Борис'));
    await tester.pumpAndSettle();
    expect(selected, 'peer-2');
    expect(find.text('Экран Борис'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fullscreen stream keeps the participant menu usable while actions are hidden',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final state = AppState(ApiClient());
      addTearDown(state.dispose);
      await loadUiuxVisualCaptureFonts();
      final captureKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: guildTheme().copyWith(platform: TargetPlatform.macOS),
            home: ScreenFullscreenOverlay(
              publisherName: 'Тест',
              video: const ColoredBox(color: Colors.black),
              onClose: () {},
              participantsOverlay: VoiceViewerParticipantsMenu(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('screen-viewer-action-hit-test')),
            )
            .ignoring,
        isTrue,
      );
      expect(
        find.byTooltip('Участники трансляции').hitTestable(),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Участники трансляции'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Закрыть панель участников'), findsOneWidget);
      await captureUiuxBoundary(
        tester,
        find.byKey(captureKey),
        fileName: 'voice-viewer-participants-fullscreen-open.png',
        pixelRatio: 1,
      );
    },
  );
}
