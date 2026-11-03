import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/features/voice/disconnect_notice/model.dart';
import 'package:boohtacord_desktop/src/widgets/voice_disconnect/notice.dart';
import 'package:boohtacord_desktop/src/widgets/voice_disconnect/join_actions.dart';

void main() {
  testWidgets('real terminal notice/actions fit phone and desktop layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final width in [390.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final reason in [
        'KICK',
        'CHANNEL_CLOSED',
        'BANNED',
        'TRANSFER',
        'TRANSPORT',
      ]) {
        final notice = VoiceDisconnectNotice(
          reason,
          reason == 'TRANSPORT' ? 'transport' : 'server',
        );
        final key = GlobalKey();
        var joins = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width < 540 ? width - 32 : 540,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VoiceDisconnectNoticeView(notice: notice),
                        const SizedBox(height: 20),
                        VoiceManualJoinActions(
                          joining: false,
                          leaving: false,
                          admissionClosed: false,
                          notice: notice,
                          onJoin: () => joins++,
                          onListen: () => joins++,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(notice.message), findsOneWidget);
        if (notice.reconnectAllowed) {
          await tester.tap(find.text('Войти'));
          await tester.tap(find.text('Без микрофона'));
          expect(joins, 2);
        } else {
          expect(
            tester
                .widget<FilledButton>(
                  find.byWidgetPredicate((w) => w is FilledButton),
                )
                .onPressed,
            isNull,
          );
        }
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            return (await image.toByteData(format: ui.ImageByteFormat.png))!
                .buffer
                .asUint8List();
          } finally {
            image.dispose();
          }
        });
        final directory = Directory('../../.out/checks/voice-notice-actual')
          ..createSync(recursive: true);
        File('${directory.path}/flutter-${width.toInt()}-$reason.png')
            .writeAsBytesSync(bytes!);
      }
    }
  });
}
