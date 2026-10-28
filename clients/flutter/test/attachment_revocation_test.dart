import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'attachment_revocation/fixture.dart';
import 'uiux_2026/capture_support.dart';

void main() {
  setUpAll(loadUiuxVisualCaptureFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final pending in [false, true]) {
    testWidgets('open image revokes on applied DM deletion, pending=$pending', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      var requests = 0;
      final state = AppState(
        ApiClient(
          client: MockClient((_) async {
            requests++;
            return pending && requests > 1 ? response.future : image();
          }),
        ),
      )..directMessageHistory = [original];
      addTearDown(state.dispose);
      await tester.pumpWidget(attachmentApp(state));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attachment-preview-image')));
      await tester.pump();
      if (!pending) {
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('protected-image-viewer-download')),
          findsOneWidget,
        );
      }
      state.directMessageHistory = [original.asDeleted()];
      state.conversation.changed();
      await tester.pumpAndSettle();
      expect(find.text('Вложение удалено или недоступно.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('protected-image-viewer-download')),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.byType(Image)),
        findsNothing,
      );
      if (pending) {
        response.complete(image());
        await tester.pumpAndSettle();
      }
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.byType(Image)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await captureUiuxBoundary(
        tester,
        find
            .ancestor(
              of: find.byType(Dialog),
              matching: find.byType(RepaintBoundary),
            )
            .first,
        fileName: 'revoked-image-pending-$pending.png',
        pixelRatio: 1,
      );
    });
  }

  testWidgets(
    'unrelated changes preserve the viewer; session replacement revokes it',
    (tester) async {
      final state = AppState(
        ApiClient(client: MockClient((_) async => image())),
      )..directMessageHistory = [original];
      addTearDown(state.dispose);
      await tester.pumpWidget(attachmentApp(state));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attachment-preview-image')));
      await tester.pumpAndSettle();
      state.conversation.changed();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('protected-image-viewer-download')),
        findsOneWidget,
      );
      state.api.transport.session.scope.begin();
      state.conversation.changed();
      await tester.pumpAndSettle();
      expect(find.text('Вложение удалено или недоступно.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('protected-image-viewer-download')),
        findsNothing,
      );
    },
  );
}
