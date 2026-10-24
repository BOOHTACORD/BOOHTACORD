import 'package:boohtacord_desktop/src/screens/screen_fullscreen_overlay.dart';
import 'package:boohtacord_desktop/src/screens/voice_screen_stage.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'uiux_2026/capture_support.dart';

void main() {
  testWidgets('desktop stage actions reveal on mouse and hide after idle', (
    tester,
  ) async {
    var activations = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme().copyWith(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: VoiceScreenStage(
            video: const ColoredBox(color: Colors.black),
            publisherName: 'Алиса',
            avatarName: 'Алиса',
            overlays: [
              Positioned(
                right: 16,
                top: 16,
                child: IconButton(
                  tooltip: 'Развернуть демонстрацию',
                  onPressed: () => activations++,
                  icon: const Icon(Icons.fullscreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final actions = find.byKey(const ValueKey('screen-viewer-action-content'));
    final slide = find.byKey(const ValueKey('screen-viewer-action-slide'));
    final hitTest = find.byKey(const ValueKey('screen-viewer-action-hit-test'));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);
    expect(tester.widget<AnimatedSlide>(slide).offset, const Offset(0, .016));
    expect(tester.widget<IgnorePointer>(hitTest).ignoring, isTrue);

    await tester.sendEventToBinding(
      const PointerHoverEvent(position: Offset(320, 240)),
    );
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    expect(tester.widget<AnimatedSlide>(slide).offset, Offset.zero);
    expect(tester.widget<IgnorePointer>(hitTest).ignoring, isFalse);
    await tester.tap(find.byTooltip('Развернуть демонстрацию'));
    expect(activations, 1);

    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);
    expect(tester.widget<AnimatedSlide>(slide).offset, const Offset(0, .016));
    expect(tester.widget<IgnorePointer>(hitTest).ignoring, isTrue);
  });

  testWidgets('touch fullscreen controls stay visible while idle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme().copyWith(platform: TargetPlatform.android),
        home: ScreenFullscreenOverlay(
          publisherName: 'Алиса',
          video: const ColoredBox(color: Colors.black),
          onClose: () {},
          onStopWatching: () {},
        ),
      ),
    );

    final actions = find.byKey(const ValueKey('screen-viewer-action-content'));
    final hitTest = find.byKey(const ValueKey('screen-viewer-action-hit-test'));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    expect(tester.widget<IgnorePointer>(hitTest).ignoring, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    expect(tester.widget<IgnorePointer>(hitTest).ignoring, isFalse);
  });

  testWidgets('desktop fullscreen controls reveal then hide after idle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme().copyWith(platform: TargetPlatform.macOS),
        home: ScreenFullscreenOverlay(
          publisherName: 'Алиса',
          video: const ColoredBox(color: Colors.black),
          onClose: () {},
          onStopWatching: () {},
        ),
      ),
    );

    final actions = find.byKey(const ValueKey('screen-viewer-action-content'));
    final hitTest = find.byKey(const ValueKey('screen-viewer-action-hit-test'));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);
    expect(find.byTooltip('Остановить просмотр'), findsOneWidget);

    await tester.sendEventToBinding(
      const PointerHoverEvent(position: Offset(320, 240)),
    );
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    expect(tester.widget<IgnorePointer>(hitTest).ignoring, isFalse);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.sendEventToBinding(
      const PointerHoverEvent(position: Offset(440, 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);
    expect(tester.widget<IgnorePointer>(hitTest).ignoring, isTrue);
  });

  testWidgets('keyboard focus keeps desktop actions visible', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme().copyWith(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: VoiceScreenStage(
            video: const ColoredBox(color: Colors.black),
            publisherName: 'Алиса',
            avatarName: 'Алиса',
            overlays: [
              Positioned(
                right: 16,
                top: 16,
                child: IconButton(
                  focusNode: focusNode,
                  tooltip: 'Закрыть просмотр',
                  onPressed: () {},
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final actions = find.byKey(const ValueKey('screen-viewer-action-content'));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);

    focusNode.requestFocus();
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
  });

  testWidgets('fullscreen action tray visual capture', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await loadUiuxVisualCaptureFonts();

    const boundaryKey = ValueKey('transient-screen-viewer-capture');
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme().copyWith(platform: TargetPlatform.macOS),
        home: RepaintBoundary(
          key: boundaryKey,
          child: ScreenFullscreenOverlay(
            publisherName: 'Алиса',
            video: const ColoredBox(color: Color(0xFF123244)),
            onClose: () {},
            onStopWatching: () {},
          ),
        ),
      ),
    );
    await tester.sendEventToBinding(
      const PointerHoverEvent(position: Offset(520, 440)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();
    final actions = find.byKey(const ValueKey('screen-viewer-action-content'));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    final fade = find.descendant(
      of: actions,
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Выйти из полноэкранного режима'), findsOneWidget);
    expect(find.byTooltip('Остановить просмотр'), findsOneWidget);
    await captureUiuxBoundary(
      tester,
      find.byKey(boundaryKey),
      fileName: 'flutter-screen-viewer-transient-controls-1440x900.png',
      pixelRatio: 1,
    );
  });
}
