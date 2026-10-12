import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:boohtacord_desktop/src/widgets/screen_share_setup_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test(
    'maps every resolution and frame-rate combination to capture settings',
    () {
      for (final resolution in ScreenShareQuality.resolutions) {
        for (final frameRate in ScreenShareQuality.frameRates) {
          final quality = ScreenShareQuality(
            resolution: resolution,
            frameRate: frameRate,
          );

          expect(quality.parameters.dimensions.height, resolution);
          expect(quality.parameters.encoding?.maxFramerate, frameRate);
          expect(quality.captureParameters.dimensions.height, 1440);
          expect(quality.captureFrameRate, 60);
          expect(quality.parameters.encoding!.maxBitrate, greaterThan(0));
          expect(
            quality.trackName,
            'screenshare-${resolution}p-${frameRate}fps',
          );
        }
      }
    },
  );

  test(
    'publishes selected profile and allows Android single-layer fallback',
    () {
      for (final resolution in ScreenShareQuality.resolutions) {
        for (final frameRate in ScreenShareQuality.frameRates) {
          final quality = ScreenShareQuality(
            resolution: resolution,
            frameRate: frameRate,
          );
          final androidOptions = quality.publishOptions(simulcast: false);
          final desktopOptions = quality.publishOptions(simulcast: true);

          expect(androidOptions.name, quality.trackName);
          expect(androidOptions.screenShareEncoding?.maxFramerate, frameRate);
          expect(
            androidOptions.screenShareEncoding?.maxBitrate,
            quality.maxBitrate * 1000,
          );
          expect(androidOptions.simulcast, isFalse);
          expect(desktopOptions.simulcast, isTrue);
        }
      }
    },
  );

  test('resolution profile scales source without cropping or upscaling', () {
    for (final resolution in ScreenShareQuality.resolutions) {
      final quality = ScreenShareQuality(resolution: resolution, frameRate: 30);
      final source = const VideoDimensions(3840, 2160);
      final scale = quality.scaleResolutionDownBy(source);
      final encoding = quality
          .publishOptions(simulcast: false, sourceDimensions: source)
          .screenShareEncoding!;
      final encodedWidth = source.width ~/ scale;
      final encodedHeight = source.height ~/ scale;

      expect(encoding.scaleResolutionDownBy, scale);
      expect(scale, greaterThanOrEqualTo(1));
      expect(
        encodedWidth,
        lessThanOrEqualTo(quality.parameters.dimensions.width),
      );
      expect(
        encodedHeight,
        lessThanOrEqualTo(quality.parameters.dimensions.height),
      );
      expect(encodedWidth.isEven, isTrue);
      expect(encodedHeight.isEven, isTrue);
    }

    final portraitSource = const VideoDimensions(1440, 3120);
    final portrait720 = const ScreenShareQuality(
      resolution: 720,
      frameRate: 30,
    );
    final portraitScale = portrait720.scaleResolutionDownBy(portraitSource);
    expect(
      portraitSource.width ~/ portraitScale,
      lessThan(portraitSource.width),
    );
    expect(portraitSource.height ~/ portraitScale, lessThanOrEqualTo(1280));
    expect(
      const ScreenShareQuality(
        resolution: 1080,
        frameRate: 30,
      ).scaleResolutionDownBy(const VideoDimensions(540, 1170)),
      1,
    );
  });

  test('reads native dimensions from the JPEG source preview', () {
    final preview = Uint8List.fromList([
      0xff, 0xd8, // SOI
      0xff, 0xe0, 0x00, 0x04, 0x00, 0x00, // APP0
      0xff, 0xc0, 0x00, 0x11, 0x08, 0x04, 0x38, 0x07, 0x80, 0x03,
      0x01, 0x11, 0x00, 0x02, 0x11, 0x00, 0x03, 0x11, 0x00, // SOF0
      0xff, 0xd9, // EOI
    ]);

    final dimensions = ScreenShareQuality.sourceDimensionsFromJpeg(preview);
    expect(dimensions?.width, 1920);
    expect(dimensions?.height, 1080);
    expect(
      ScreenShareQuality.sourceDimensionsFromJpeg(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      ),
      isNull,
    );
    expect(ScreenShareQuality.sourceDimensionsFromJpeg(null), isNull);
  });

  testWidgets('Android setup returns selected resolution and FPS', (
    tester,
  ) async {
    ScreenShareSetupSelection? result;
    await tester.pumpWidget(
      MaterialApp(
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
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Дополнительные настройки качества'));
    await tester.tap(find.text('Дополнительные настройки качества'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1440p'));
    await tester.tap(find.text('1440p'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('60 FPS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 FPS'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-screen-share')));
    await tester.pumpAndSettle();

    expect(result?.sourceId, isNull);
    expect(result?.quality.resolution, 1440);
    expect(result?.quality.frameRate, 60);
  });

  testWidgets('keeps keyboard traversal inside screen-share setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScreenShareSetupDialog.show(
                context,
                initialQuality: ScreenShareQuality.balanced,
                allowSourceSelection: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialogScope = FocusScope.of(tester.element(find.byType(Dialog)));
    expect(dialogScope.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);
    final focusables = dialogScope.traversalDescendants
        .where((node) => node.context != null)
        .toList();
    expect(focusables, isNotEmpty);

    focusables.last.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusables, contains(FocusManager.instance.primaryFocus));

    focusables.first.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(focusables, contains(FocusManager.instance.primaryFocus));
  });

  testWidgets('iOS setup explains app-only capture before starting', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    ScreenShareSetupSelection? result;
    await tester.pumpWidget(
      MaterialApp(
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
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Чтобы запросить звук игры или приложения'),
      findsOneWidget,
    );
    expect(find.text('Весь экран'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('start-screen-share')));
    await tester.pumpAndSettle();
    expect(result?.quality, ScreenShareQuality.balanced);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop setup omits mobile capture guidance', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScreenShareSetupDialog.show(
                context,
                initialQuality: ScreenShareQuality.balanced,
                allowSourceSelection: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'При выборе отдельного приложения Android может скрыть его изображение',
      ),
      findsNothing,
    );
    expect(find.textContaining('На iPhone транслируется'), findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('hides mobile capture guidance while changing quality', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScreenShareSetupDialog.show(
                context,
                initialQuality: ScreenShareQuality.balanced,
                allowSourceSelection: false,
                updating: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Для применения нового профиля захвата остановите'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Android покажет системный запрос'),
      findsNothing,
    );
    expect(
      find.textContaining(
        'При выборе отдельного приложения Android может скрыть его изображение',
      ),
      findsNothing,
    );
    expect(find.text('Применить качество'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('explains Android app-only capture visibility before starting', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScreenShareSetupDialog.show(
                context,
                initialQuality: ScreenShareQuality.balanced,
                allowSourceSelection: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'При выборе отдельного приложения Android может скрыть его изображение',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('does not show Android-specific quality-picker guidance', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScreenShareSetupDialog.show(
                context,
                initialQuality: ScreenShareQuality.balanced,
                allowSourceSelection: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Дополнительные настройки качества'));
    await tester.tap(find.text('Дополнительные настройки качества'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Android покажет системный запрос'),
      findsNothing,
    );
    expect(find.textContaining('запрос на запись экрана'), findsNothing);
    expect(find.text('Разрешение'), findsOneWidget);
    expect(find.text('Частота кадров'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keeps quality options on one line in Android portrait', (
    tester,
  ) async {
    // 576 physical pixels at a typical Android density is a 360 logical-pixel
    // viewport, matching the narrow phone layout rather than a tablet-sized
    // 576 logical-pixel canvas.
    tester.view.devicePixelRatio = 1.6;
    tester.view.physicalSize = const Size(576, 1280);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScreenShareSetupDialog.show(
                context,
                initialQuality: ScreenShareQuality.balanced,
                allowSourceSelection: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Дополнительные настройки качества'));
    await tester.tap(find.text('Дополнительные настройки качества'));
    await tester.pumpAndSettle();

    for (final label in [
      '720p',
      '1080p',
      '1440p',
      '15 FPS',
      '30 FPS',
      '60 FPS',
    ]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
    }
    final resolutionLabel = tester.getRect(find.text('Разрешение'));
    final resolutionSegments = tester.getRect(
      find.byKey(const ValueKey('resolution-segments')),
    );
    final frameRateLabel = tester.getRect(find.text('Частота кадров'));
    final frameRateSegments = tester.getRect(
      find.byKey(const ValueKey('frame-rate-segments')),
    );
    expect(resolutionSegments.width, greaterThan(230));
    expect(resolutionSegments.width, lessThan(300));
    expect(resolutionLabel.bottom, lessThan(resolutionSegments.top));
    expect(frameRateLabel.bottom, lessThan(frameRateSegments.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Android picker usable at the minimum 320 dp width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScreenShareSetupDialog.show(
                context,
                initialQuality: ScreenShareQuality.balanced,
                allowSourceSelection: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Дополнительные настройки качества'));
    await tester.tap(find.text('Дополнительные настройки качества'));
    await tester.pumpAndSettle();

    final start = tester.getRect(
      find.byKey(const ValueKey('start-screen-share')),
    );
    for (final label in [
      '720p',
      '1080p',
      '1440p',
      '15 FPS',
      '30 FPS',
      '60 FPS',
    ]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
    }
    expect(start.bottom, lessThanOrEqualTo(640));
    await tester.ensureVisible(
      find.byKey(const ValueKey('resolution-segments')),
    );
    await tester.pumpAndSettle();
    final visibleResolution = tester.getRect(
      find.byKey(const ValueKey('resolution-segments')),
    );
    expect(visibleResolution.top, greaterThanOrEqualTo(0));
    expect(visibleResolution.bottom, lessThanOrEqualTo(640));

    await tester.ensureVisible(
      find.byKey(const ValueKey('frame-rate-segments')),
    );
    await tester.pumpAndSettle();
    final visibleFrameRate = tester.getRect(
      find.byKey(const ValueKey('frame-rate-segments')),
    );
    expect(visibleFrameRate.top, greaterThanOrEqualTo(0));
    expect(visibleFrameRate.bottom, lessThanOrEqualTo(640));
    expect(
      tester.getRect(find.byKey(const ValueKey('start-screen-share'))).bottom,
      lessThanOrEqualTo(640),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('start-screen-share')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
