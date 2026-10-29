import 'dart:ui' as ui;

import 'package:boohtacord_desktop/src/screens/workspace_ui/direct_conversation/component.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/widgets/message_attachment_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../uiux_2026/capture_support.dart';
import 'fixture.dart';
import 'image_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiuxVisualCaptureFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final gif in [false, true]) {
    testWidgets(
      'own ${gif ? 'GIF' : 'JPEG'} row survives explicit Send without realtime',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final f = SendFixture(extension: gif ? 'gif' : 'jpg')
          ..originalBytes = gif ? gifOriginal : jpegOriginal
          ..previewBytes = gif ? gifPreview : jpegPreview;
        addTearDown(f.dispose);
        final codec = await tester.runAsync(
          () => ui.instantiateImageCodec(gif ? gifOriginal : jpegOriginal),
        );
        expect(codec!.frameCount, gif ? 2 : 1);
        codec.dispose();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: guildTheme().copyWith(platform: TargetPlatform.android),
              home: Scaffold(
                body: AnimatedBuilder(
                  animation: f.state,
                  builder: (_, _) => WorkspaceDirectConversation(
                    state: f.state,
                    conversation: pair,
                  ),
                ),
              ),
            ),
          ),
        );
        // Stage metadata from a completed protected upload; OS picker is separate.
        tester
            .widget<MessageAttachmentComposer>(
              find.byType(MessageAttachmentComposer),
            )
            .onChanged([f.file]);
        await tester.pumpAndSettle();
        expect(find.byType(InputChip), findsOneWidget);
        expect(f.posts, 0);
        await tester.tap(find.byTooltip('Отправить личное сообщение'));
        await tester.runAsync(
          () => f.historyRequested.future.timeout(const Duration(seconds: 2)),
        );
        await tester.pumpAndSettle();
        expect(f.state.sending, isFalse);
        expect(f.posts, 1);
        expect(f.historyReads, 1);
        expect(f.state.realtime.connected, isFalse);
        expect(find.byType(InputChip), findsNothing);
        expect(find.text(f.file.originalName), findsOneWidget);
        expect(
          find.byTooltip('Открыть изображение ${f.file.originalName}'),
          findsOneWidget,
        );
        for (var attempt = 0; attempt < 20; attempt++) {
          if (tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((image) => image.image != null)) {
            break;
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .where((image) => image.image != null),
          isNotEmpty,
        );
        expect(tester.takeException(), isNull);
        await captureUiuxBoundary(
          tester,
          find.byKey(boundary),
          fileName: 'dm-attachment-send-${gif ? 'gif' : 'jpeg'}.png',
          pixelRatio: 1,
        );
      },
    );
  }
}
