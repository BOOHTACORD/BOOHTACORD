import 'package:boohtacord_desktop/src/widgets/screen_share_setup_dialog.dart';
import 'package:boohtacord_desktop/src/features/screen/setup/open_dialog/footer.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import 'source_support.dart';

void main() {
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.fuchsia,
  ]) {
    testWidgets(
      'pre-picker capability and cancel preserve null selection on $platform',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        ScreenShareSetupSelection? result;
        var closed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('open'),
                  onPressed: () async {
                    result = await ScreenShareSetupDialog.show(
                      context,
                      initialQuality: ScreenShareQuality.balanced,
                      allowSourceSelection: false,
                    );
                    closed = true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('screen-preflight-capabilities')),
          findsOneWidget,
        );
        final audioToggle = find.byKey(const ValueKey('capture-screen-audio'));
        if (platform == TargetPlatform.fuchsia) {
          expect(audioToggle, findsNothing);
        } else {
          expect(tester.widget<SwitchListTile>(audioToggle).value, isFalse);
        }
        final audioMessage = switch (platform) {
          TargetPlatform.android => 'Android 10+: понадобится разрешение записи аудио; приложение-источник может запретить захват.',
          TargetPlatform.iOS => 'iOS: звук передаётся через системный ReplayKit broadcast; приложение-источник может ограничить захват.',
          _ => 'Звук экрана на этой платформе недоступен.',
        };
        expect(find.text(audioMessage), findsOneWidget);
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('start-screen-share')),
        );
        expect(button.onPressed != null, platform != TargetPlatform.fuchsia);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(closed, isTrue);
        expect(result, isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
  testWidgets('mobile quality choice is preserved in accepted result', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenShareSetupDialog(
          initialQuality: ScreenShareQuality.balanced,
          allowSourceSelection: false,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Дополнительные настройки качества'));
    await tester.tap(find.text('Дополнительные настройки качества'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1080p'));
    await tester.tap(find.text('1080p'));
    await tester.pump();
    final button = tester.widget<SegmentedButton<int>>(
      find.descendant(
        of: find.byKey(const ValueKey('resolution-segments')),
        matching: find.byType(SegmentedButton<int>),
      ),
    );
    expect(button.selected, {1080});
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets(
    'setup recommends a starting profile and progressively reveals quality options',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          home: Scaffold(
            body: ScreenShareSetupDialog(
              initialQuality: ScreenShareQuality.balanced,
              allowSourceSelection: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Рекомендуемый профиль'), findsOneWidget);
      expect(find.text('1080p · 60 FPS'), findsOneWidget);
      expect(find.text('Текущий выбор: 720p · 15 FPS'), findsOneWidget);
      expect(find.text('Разрешение'), findsNothing);

      await tester.ensureVisible(
        find.text('Применить рекомендованный профиль'),
      );
      await tester.tap(find.text('Применить рекомендованный профиль'));
      await tester.pumpAndSettle();
      expect(find.text('Текущий выбор: 1080p · 60 FPS'), findsOneWidget);

      await tester.ensureVisible(
        find.text('Дополнительные настройки качества'),
      );
      await tester.tap(find.text('Дополнительные настройки качества'));
      await tester.pumpAndSettle();
      expect(find.text('Разрешение'), findsOneWidget);
      expect(find.text('Частота кадров'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'setup keeps its actions reachable with the mobile keyboard and 2x text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ScreenShareSetupDialog.show(
                  context,
                  initialQuality: ScreenShareQuality.balanced,
                  allowSourceSelection: false,
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cancel = find.byTooltip('Закрыть');
      final start = find.byKey(const ValueKey('start-screen-share'));
      await tester.ensureVisible(cancel);
      await tester.ensureVisible(start);
      expect(tester.getRect(start).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(start).bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'compact source inventory scrolls and confirms the selected source',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      final capturer = FakeDesktopCapturer();
      addTearDown(capturer.close);
      ScreenShareSetupSelection? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await ScreenShareSetupDialog.show(
                    context,
                    initialQuality: ScreenShareQuality.desktopDefault,
                    allowSourceSelection: true,
                    capturer: capturer,
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(capturer.calls, hasLength(1));
      capturer.calls.single.complete([
        for (var index = 1; index <= 8; index++)
          FakeSource('Экран $index', rtc.SourceType.Screen),
      ]);
      await tester.pumpAndSettle();

      final source = find.text('Экран 8');
      await tester.ensureVisible(source);
      expect(tester.getRect(source).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(source).bottom, lessThanOrEqualTo(640));
      await tester.tap(source);
      await tester.pumpAndSettle();
      expect(find.text('Выбрано: Экран 8'), findsOneWidget);

      final cancel = find.text('Отмена');
      final start = find.byKey(const ValueKey('start-screen-share'));
      await tester.ensureVisible(cancel);
      await tester.ensureVisible(start);
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(640));
      expect(tester.getRect(start).bottom, lessThanOrEqualTo(640));
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(result?.sourceId, 'Экран 8');
      expect(result?.quality, ScreenShareQuality.desktopDefault);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'mobile setup keeps close and start reachable above the keyboard',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  await ScreenShareSetupDialog.show(
                    context,
                    initialQuality: ScreenShareQuality.desktopDefault,
                    allowSourceSelection: false,
                  );
                  closed = true;
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      final cancel = find.byTooltip('Закрыть');
      final start = find.byKey(const ValueKey('start-screen-share'));
      expect(cancel, findsOneWidget);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(360));
      expect(tester.getRect(start).bottom, lessThanOrEqualTo(360));
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'landscape source picker scrolls to later screens without hiding actions',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.reset);
      final capturer = FakeDesktopCapturer();
      addTearDown(capturer.close);
      ScreenShareSetupSelection? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await ScreenShareSetupDialog.show(
                    context,
                    initialQuality: ScreenShareQuality.desktopDefault,
                    allowSourceSelection: true,
                    capturer: capturer,
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pump(const Duration(milliseconds: 400));
      capturer.calls.single.complete([
        for (var index = 1; index <= 8; index++)
          FakeSource('Экран $index', rtc.SourceType.Screen),
      ]);
      await tester.pumpAndSettle();

      final source = find.text('Экран 8');
      await tester.ensureVisible(source);
      expect(tester.getRect(source).bottom, lessThanOrEqualTo(390));
      await tester.tap(source);
      await tester.pumpAndSettle();
      expect(find.text('Выбрано: Экран 8'), findsOneWidget);

      final cancel = find.text('Отмена');
      final start = find.byKey(const ValueKey('start-screen-share'));
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(390));
      expect(tester.getRect(start).bottom, lessThanOrEqualTo(390));
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(result?.sourceId, 'Экран 8');
      expect(result?.quality, ScreenShareQuality.desktopDefault);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  const viewports = <({String name, Size size})>[
    (name: 'compact', size: Size(320, 640)),
    (name: 'medium', size: Size(768, 1024)),
    (name: 'expanded', size: Size(1440, 900)),
  ];
  for (final viewport in viewports) {
    for (final textScale in [1.0, 2.0]) {
      for (final keyboardOpen in [false, true]) {
        testWidgets(
          'setup actions stay in the safe viewport on ${viewport.name}, '
          '${textScale}x text, keyboard ${keyboardOpen ? 'open' : 'closed'}',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = viewport.size;
            tester.view.viewPadding = const FakeViewPadding(
              top: 24,
              bottom: 24,
            );
            tester.view.viewInsets = FakeViewPadding(
              bottom: keyboardOpen ? 280 : 0,
            );
            addTearDown(tester.view.reset);

            ScreenShareSetupSelection? result;
            await tester.pumpWidget(
              MaterialApp(
                theme: guildTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        result = await ScreenShareSetupDialog.show(
                          context,
                          initialQuality: ScreenShareQuality.balanced,
                          allowSourceSelection: false,
                        );
                      },
                      child: const Text('Открыть'),
                    ),
                  ),
                ),
              ),
            );

            await tester.tap(find.text('Открыть'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            final close = find.byTooltip('Закрыть');
            final start = find.byKey(const ValueKey('start-screen-share'));
            expect(close, findsOneWidget);
            expect(start, findsOneWidget);
            expect(Theme.of(tester.element(start)).brightness, Brightness.dark);
            await tester.ensureVisible(close);
            await tester.ensureVisible(start);
            final startRect = tester.getRect(start);
            expect(startRect.left, greaterThanOrEqualTo(0));
            expect(startRect.right, lessThanOrEqualTo(viewport.size.width));
            expect(
              startRect.bottom,
              lessThanOrEqualTo(
                viewport.size.height -
                    (keyboardOpen ? 280 : 0) -
                    (keyboardOpen ? 0 : 24),
              ),
            );
            expect(tester.takeException(), isNull);

            await tester.tap(
              keyboardOpen && viewport.size.width < 400
                  ? close
                  : find.text('Отмена'),
            );
            await tester.pumpAndSettle();
            expect(result, isNull);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant({TargetPlatform.android}),
        );
      }
    }
  }

  testWidgets(
    'large text wraps screen-share actions without hiding source context',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(768, 1024);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 728,
              child: SetupFooter(
                canStart: true,
                updating: false,
                selecting: true,
                keyboardConstrained: false,
                selectedName: 'Тестовое окно',
                onCancel: _ignore,
                onStart: _ignore,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Выбрано: Тестовое окно'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      expect(find.byKey(const ValueKey('start-screen-share')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final cancel = tester.getRect(find.text('Отмена'));
      final start = tester.getRect(
        find.byKey(const ValueKey('start-screen-share')),
      );
      expect(cancel.left, greaterThanOrEqualTo(0));
      expect(start.right, lessThanOrEqualTo(768));
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}

void _ignore() {}
