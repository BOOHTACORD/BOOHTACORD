import 'dart:typed_data';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_participant_card/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;

import 'uiux_2026/capture_support.dart';

void main() {
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
                    width: 360,
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
                      previewCaption: 'Экран · 1080p · 60 FPS',
                      onScreenTap: () => selected++,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 360,
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
    expect(streamPreviewSize.width, 358);
    expect(streamPreviewSize.height, closeTo(358 * 9 / 16, 0.1));
    expect(tester.getSize(voicePreview), streamPreviewSize);
    expect(find.text('Экран · 1080p · 60 FPS'), findsOneWidget);
    expect(find.text('ЭФИР'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(find.text('В голосовом канале'), findsOneWidget);
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
