import 'dart:typed_data';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_participant_card/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_participant_room/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;

import 'uiux_2026/capture_support.dart';

void main() {
  testWidgets('participant room follows web heading, count and card width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 620);
    addTearDown(tester.view.reset);

    final api = ApiClient(
      client: MockClient((_) async => throw StateError('unexpected request')),
    );
    final state = AppState(api)
      ..voicePhase = VoicePhase.listener
      ..screenSharePhase = ScreenSharePhase.sharing;
    await loadUiuxVisualCaptureFonts();
    final captureKey = GlobalKey();
    addTearDown(() {
      state.dispose();
      api.transport.raw.close();
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: guildTheme(),
          home: Scaffold(
            body: WorkspaceVoiceParticipantRoom(
              state: state,
              room: null,
              participants: const [],
              screens: const [],
              onScreenSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Режим слушателя'), findsOneWidget);
    expect(find.text('1 участник · 1 демонстрация экрана'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('voice-participant-card:self')))
          .width,
      280,
    );
    expect(tester.takeException(), isNull);
    await captureUiuxBoundary(
      tester,
      find.byKey(captureKey),
      fileName: 'flutter-listener-room-web-parity.png',
      pixelRatio: 1,
    );
  });

  testWidgets('pending stream preview fits narrow cards with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.reset);

    final api = ApiClient(
      client: MockClient((_) async => throw StateError('unexpected request')),
    );
    final state = AppState(api);
    addTearDown(() {
      state.dispose();
      api.transport.raw.close();
    });
    await loadUiuxVisualCaptureFonts();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: guildTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 286,
                child: WorkspaceVoiceParticipantCard(
                  state: state,
                  name: 'Streamer',
                  avatarUrl: null,
                  muted: true,
                  speaking: false,
                  hasScreen: true,
                  previewIdentity: 'stream-pending-large-text',
                  previewCaption: 'Экран · 1080p · 60 FPS',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Трансляция идёт'), findsOneWidget);
    expect(find.text('Предпросмотр скоро появится'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('voice-only preview wraps at narrow width and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 520);
    addTearDown(tester.view.reset);

    final api = ApiClient(
      client: MockClient((_) async => throw StateError('unexpected request')),
    );
    final state = AppState(api);
    addTearDown(() {
      state.dispose();
      api.transport.raw.close();
    });
    await loadUiuxVisualCaptureFonts();
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: guildTheme(),
        home: RepaintBoundary(
          key: captureKey,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 520),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: WorkspaceVoiceParticipantCard(
                    state: state,
                    name: 'Listener',
                    avatarUrl: null,
                    muted: false,
                    speaking: false,
                    previewIdentity: 'voice-only-large-text',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final status = find.text('В голосовом канале');
    expect(status, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(status).didExceedMaxLines,
      isFalse,
    );
    final name = find.text('Listener');
    expect(name, findsOneWidget);
    expect(tester.getSize(name).width, greaterThan(0));
    expect(tester.takeException(), isNull);
    await captureUiuxBoundary(
      tester,
      find.byKey(captureKey),
      fileName: 'flutter-participant-cards-mobile-large-text.png',
      pixelRatio: 1,
    );
  });

  testWidgets('stream and voice-only participant cards share the same layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 620);
    addTearDown(tester.view.reset);

    final api = ApiClient(
      client: MockClient((_) async => throw StateError('unexpected request')),
    );
    final state = AppState(api);
    addTearDown(() {
      state.dispose();
      api.transport.raw.close();
    });
    final thumbnail = Uint8List.fromList(image.encodeJpg(_previewFrame()));
    var selected = 0;
    await loadUiuxVisualCaptureFonts();
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: guildTheme(),
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 288,
                    child: WorkspaceVoiceParticipantCard(
                      key: const ValueKey('stream-card'),
                      state: state,
                      name: 'Streamer',
                      avatarUrl: null,
                      muted: true,
                      speaking: false,
                      hasScreen: true,
                      previewIdentity: 'stream',
                      previewThumbnail: thumbnail,
                      previewCaption: '1080p · 60 FPS',
                      onScreenTap: () => selected++,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 288,
                    child: WorkspaceVoiceParticipantCard(
                      key: const ValueKey('voice-card'),
                      state: state,
                      name: 'Listener',
                      avatarUrl: null,
                      muted: false,
                      speaking: false,
                      previewIdentity: 'voice-only',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final streamCard = find.byKey(const ValueKey('stream-card'));
    final voiceCard = find.byKey(const ValueKey('voice-card'));
    final streamPreview = find.byKey(
      const ValueKey('voice-participant-preview:stream'),
    );
    final voicePreview = find.byKey(
      const ValueKey('voice-participant-preview:voice-only'),
    );
    expect(tester.getSize(streamCard), tester.getSize(voiceCard));
    final streamPreviewSize = tester.getSize(streamPreview);
    expect(streamPreviewSize.width, lessThan(288));
    expect(streamPreviewSize.width, greaterThan(270));
    expect(
      streamPreviewSize.height,
      closeTo(streamPreviewSize.width * 9 / 16, 0.1),
    );
    expect(tester.getSize(voicePreview), streamPreviewSize);
    expect(find.text('1080p · 60 FPS'), findsOneWidget);
    final captionSize = tester.getSize(
      find.byKey(const ValueKey('participant-screen-preview-caption')),
    );
    if (uiuxVisualCaptureEnabled) {
      final captionTextIntrinsicWidth = tester
          .renderObject<RenderParagraph>(find.text('1080p · 60 FPS'))
          .getMaxIntrinsicWidth(double.infinity);
      expect(captionSize.width, closeTo(captionTextIntrinsicWidth + 14, 0.5));
      expect(captionSize.width, lessThan(streamPreviewSize.width / 2));
    }
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('participant-screen-preview-caption')),
          )
          .right,
      lessThan(
        tester
            .getRect(
              find.byKey(const ValueKey('participant-screen-preview-live')),
            )
            .left,
      ),
    );
    expect(find.textContaining('Экран'), findsNothing);
    expect(find.text('ЭФИР'), findsOneWidget);
    final playButton = find.byKey(
      const ValueKey('participant-screen-preview-play'),
    );
    expect(playButton, findsOneWidget);
    expect(tester.getSize(playButton), const Size(36, 36));
    expect(find.text('В голосовом канале'), findsOneWidget);
    expect(find.text('Микрофон выключен'), findsNothing);
    final nameRect = tester.getRect(find.text('Streamer'));
    final muteRect = tester.getRect(find.byIcon(Icons.mic_off));
    expect((nameRect.center.dy - muteRect.center.dy).abs(), lessThan(4));
    expect(find.text('Смотреть экран'), findsNothing);

    final renderedThumbnail = tester.widget<Image>(find.byType(Image));
    expect(renderedThumbnail.image, isA<MemoryImage>());
    expect((renderedThumbnail.image as MemoryImage).bytes, same(thumbnail));

    await tester.runAsync(
      () =>
          precacheImage(MemoryImage(thumbnail), tester.element(streamPreview)),
    );
    await tester.pump();

    await captureUiuxBoundary(
      tester,
      find.byKey(captureKey),
      fileName: 'flutter-participant-cards-stream-and-voice.png',
      pixelRatio: 1,
    );

    await tester.tap(streamPreview);
    await tester.pump();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading participant preview uses the web copy without play icon',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 520);
      addTearDown(tester.view.reset);

      final api = ApiClient(
        client: MockClient((_) async => throw StateError('unexpected request')),
      );
      final state = AppState(api);
      await loadUiuxVisualCaptureFonts();
      final captureKey = GlobalKey();
      addTearDown(() {
        state.dispose();
        api.transport.raw.close();
      });

      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: guildTheme(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 288,
                  child: WorkspaceVoiceParticipantCard(
                    state: state,
                    name: 'Streamer',
                    avatarUrl: null,
                    muted: true,
                    speaking: false,
                    hasScreen: true,
                    previewIdentity: 'stream-loading',
                    previewCaption: '',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Трансляция идёт'), findsOneWidget);
      expect(find.text('Предпросмотр скоро появится'), findsOneWidget);
      expect(find.textContaining('Экран'), findsNothing);
      expect(
        find.byKey(const ValueKey('participant-screen-preview-play')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await captureUiuxBoundary(
        tester,
        find.byKey(captureKey),
        fileName: 'flutter-participant-preview-loading.png',
        pixelRatio: 1,
      );
    },
  );
}

image.Image _previewFrame() {
  final frame = image.Image(width: 480, height: 270);
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      frame.setPixelRgba(
        x,
        y,
        25 + x * 120 ~/ frame.width,
        30 + y * 70 ~/ frame.height,
        85 + x * 100 ~/ frame.width,
        255,
      );
    }
  }
  return frame;
}
