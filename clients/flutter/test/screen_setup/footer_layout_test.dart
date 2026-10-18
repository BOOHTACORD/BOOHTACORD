import 'package:boohtacord_desktop/src/features/screen/setup/open_dialog/dialog.dart';
import 'package:boohtacord_desktop/src/features/screen/setup/open_dialog/footer.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import 'source_support.dart';

void visibleActions(WidgetTester tester, Size size) {
  final surface = tester.getRect(
    find
        .ancestor(of: find.byType(SetupFooter), matching: find.byType(Material))
        .first,
  );
  final bounds = (Offset.zero & size).deflate(20).intersect(surface);
  for (final finder in [
    find.widgetWithText(TextButton, 'Отмена'),
    find.byKey(const ValueKey('start-screen-share')),
    find.byTooltip('Закрыть'),
  ]) {
    final rect = tester.getRect(finder);
    expect(bounds.contains(rect.topLeft), isTrue, reason: '$finder $rect');
    expect(bounds.contains(rect.bottomRight), isTrue, reason: '$finder $rect');
    expect(finder.hitTestable(), findsOneWidget);
  }
  expect(tester.takeException(), isNull);
}

void main() {
  for (final size in [
    const Size(1008, 720),
    const Size(1024, 768),
    const Size(800, 680),
    const Size(1440, 900),
  ]) {
    for (final inventory in ['pending', 'empty', 'sources']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$size $inventory ${scale}x keeps actions outside scroll', (
          tester,
        ) async {
          final capturer = FakeDesktopCapturer();
          addTearDown(capturer.close);
          var returned = false;
          ScreenShareSetupSelection? result;
          await open(tester, size, scale, capturer, (value) {
            returned = true;
            result = value;
          });
          if (inventory != 'pending') {
            capturer.calls.single.complete([
              if (inventory == 'sources')
                for (var i = 0; i < 12; i++)
                  FakeSource('Screen $i', rtc.SourceType.Screen),
            ]);
            await tester.pump(const Duration(milliseconds: 350));
          }
          visibleActions(tester, size);
          if (inventory == 'sources') {
            final last = find.byKey(const ValueKey('Screen 11'));
            await tester.ensureVisible(last);
            await tester.pump(const Duration(milliseconds: 350));
            expect(last.hitTestable(), findsOneWidget);
            await tester.tap(last);
            await tester.pump();
          }
          final footerBefore = tester.getRect(find.byType(SetupFooter));
          final advanced = find.byKey(
            const ValueKey('screen-share-advanced-quality'),
          );
          await tester.ensureVisible(advanced);
          await tester.tap(advanced);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          for (final text in ['720p', '30 FPS', 'Текст']) {
            final option = find.text(text);
            await tester.ensureVisible(option);
            await tester.pump(const Duration(milliseconds: 350));
            expect(
              option.hitTestable(),
              findsOneWidget,
              reason:
                  '${tester.getRect(option)} scroll=${tester.getRect(find.byType(SingleChildScrollView).first)}',
            );
            await tester.tap(option);
          }
          visibleActions(tester, size);
          expect(tester.getRect(find.byType(SetupFooter)), footerBefore);
          // A pointer cancellation must discard edited quality, including
          // while the source enumeration is still pending.
          await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
          await tester.pump(const Duration(milliseconds: 350));
          expect(returned, isTrue);
          expect(result, isNull);
          for (final call in capturer.calls) {
            if (!call.isCompleted) call.complete([]);
          }
          await tester.pump(const Duration(seconds: 5));
          expect(capturer.onAdded.hasListener, isFalse);
          expect(tester.takeException(), isNull);
        }, variant: TargetPlatformVariant({TargetPlatform.windows}));
      }
    }
  }

  testWidgets('short window applies edited quality by keyboard', (
    tester,
  ) async {
    ScreenShareSetupSelection? result;
    await open(
      tester,
      const Size(800, 680),
      2,
      null,
      (value) => result = value,
    );
    for (final text in ['720p', '30 FPS', 'Текст']) {
      final option = find.text(text);
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
    }
    visibleActions(tester, const Size(800, 680));
    final start = find.byKey(const ValueKey('start-screen-share'));
    Focus.of(
      tester.element(find.descendant(of: start, matching: find.byType(Text))),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      result?.quality,
      const ScreenShareQuality(resolution: 720, frameRate: 30),
    );
    expect(result?.contentMode.name, 'text');
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));
}

Future<void> open(
  WidgetTester tester,
  Size size,
  double scale,
  FakeDesktopCapturer? capturer,
  ValueChanged<ScreenShareSetupSelection?> result,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: guildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            child: const Text('Open'),
            onPressed: () async => result(
              await ScreenShareSetupDialog.show(
                context,
                initialQuality: const ScreenShareQuality(
                  resolution: 1080,
                  frameRate: 30,
                ),
                allowSourceSelection: capturer != null,
                updating: capturer == null,
                capturer: capturer,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}
