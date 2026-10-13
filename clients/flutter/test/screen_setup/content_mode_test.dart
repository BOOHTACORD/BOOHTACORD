import 'package:boohtacord_desktop/src/features/screen/profile/content_mode.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:boohtacord_desktop/src/widgets/screen_share_setup_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fps in [30, 60]) {
    testWidgets('motion remains explicit at $fps FPS', (tester) async {
      dynamic selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('open'),
                onPressed: () async =>
                    selected = await ScreenShareSetupDialog.show(
                      context,
                      initialQuality: ScreenShareQuality(
                        resolution: 1080,
                        frameRate: fps,
                      ),
                      allowSourceSelection: false,
                      updating: true,
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('screen-content-motion')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('screen-content-motion')),
            )
            .selected,
        true,
      );
      await tester.tap(find.byKey(const ValueKey('start-screen-share')));
      await tester.pumpAndSettle();
      expect(selected.contentMode, ScreenShareContentMode.motion);
      expect(selected.quality.frameRate, fps);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }
  testWidgets('text selection remains explicit at 60 FPS', (tester) async {
    dynamic selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('open'),
              onPressed: () async =>
                  selected = await ScreenShareSetupDialog.show(
                    context,
                    initialQuality: const ScreenShareQuality(
                      resolution: 1080,
                      frameRate: 60,
                    ),
                    allowSourceSelection: false,
                    updating: true,
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final text = find.byKey(const ValueKey('screen-content-text'));
    await tester.ensureVisible(text);
    await tester.tap(text);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-screen-share')));
    await tester.pumpAndSettle();
    expect(selected.contentMode, ScreenShareContentMode.text);
    expect(selected.quality.frameRate, 60);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
  for (final fps in [30, 60]) {
    testWidgets('restores text mode independently at $fps FPS', (tester) async {
      ScreenShareSetupSelection? selected;
      await _open(
        tester,
        fps: fps,
        initialMode: ScreenShareContentMode.text,
        onResult: (value) => selected = value,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('screen-content-text')),
            )
            .selected,
        true,
      );
      await tester.tap(find.byKey(const ValueKey('start-screen-share')));
      await tester.pumpAndSettle();
      expect(selected?.contentMode, ScreenShareContentMode.text);
      expect(selected?.quality.frameRate, fps);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }
  testWidgets('FPS and resolution changes preserve selected text mode', (
    tester,
  ) async {
    ScreenShareSetupSelection? selected;
    await _open(tester, onResult: (value) => selected = value);
    final text = find.byKey(const ValueKey('screen-content-text'));
    await tester.ensureVisible(text);
    await tester.tap(text);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('30 FPS'));
    await tester.tap(find.text('30 FPS'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('720p'));
    await tester.tap(find.text('720p'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(text).selected, true);
    await tester.tap(find.byKey(const ValueKey('start-screen-share')));
    await tester.pumpAndSettle();
    expect(selected?.contentMode, ScreenShareContentMode.text);
    expect(
      selected?.quality,
      const ScreenShareQuality(resolution: 720, frameRate: 30),
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
  for (final width in [320.0, 393.0]) {
    testWidgets('mode controls stay reachable at $width and 2x text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);
      ScreenShareSetupSelection? selected;
      await _open(tester, textScale: 2, onResult: (value) => selected = value);
      for (final mode in ScreenShareContentMode.values) {
        final chip = find.byKey(ValueKey('screen-content-${mode.name}'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(chip);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(width));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(800));
        expect(tester.widget<ChoiceChip>(chip).selected, true);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const ValueKey('start-screen-share')));
      await tester.pumpAndSettle();
      expect(selected?.contentMode, ScreenShareContentMode.text);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }
  testWidgets('cancel does not return changed mode', (tester) async {
    var returned = false;
    ScreenShareSetupSelection? selected;
    await _open(
      tester,
      onResult: (value) {
        selected = value;
        returned = true;
      },
    );
    final text = find.byKey(const ValueKey('screen-content-text'));
    await tester.ensureVisible(text);
    await tester.tap(text);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(returned, true);
    expect(selected, isNull);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
}

Future<void> _open(
  WidgetTester tester, {
  required ValueChanged<ScreenShareSetupSelection?> onResult,
  int fps = 60,
  ScreenShareContentMode initialMode = ScreenShareContentMode.motion,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            child: const Text('open'),
            onPressed: () async => onResult(
              await ScreenShareSetupDialog.show(
                context,
                initialQuality: ScreenShareQuality(
                  resolution: 1080,
                  frameRate: fps,
                ),
                initialContentMode: initialMode,
                allowSourceSelection: false,
                updating: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
