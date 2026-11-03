import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/disconnect_notice/model.dart';
import 'package:boohtacord_desktop/src/widgets/voice_disconnect/notice.dart';
import 'package:boohtacord_desktop/src/widgets/voice_disconnect/join_actions.dart';

void main() {
  testWidgets(
    'kick enables both manual join modes and access revocations disable them',
    (tester) async {
      var joins = 0, listens = 0;
      for (final reason in [
        'KICK',
        'CHANNEL_CLOSED',
        'BANNED',
        'SESSION_REVOKED',
        'LOGOUT',
        'TRANSFER',
        'TRANSPORT',
      ]) {
        final notice = VoiceDisconnectNotice(
          reason,
          reason == 'TRANSPORT' ? 'transport' : 'server',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceManualJoinActions(
                joining: false,
                leaving: false,
                admissionClosed: false,
                notice: notice,
                onJoin: () => joins++,
                onListen: () => listens++,
              ),
            ),
          ),
        );
        final first = tester.widget<FilledButton>(
          find.byWidgetPredicate((widget) => widget is FilledButton),
        );
        final second = tester.widget<OutlinedButton>(
          find.byWidgetPredicate((widget) => widget is OutlinedButton),
        );
        expect(first.onPressed != null, notice.reconnectAllowed);
        expect(second.onPressed != null, notice.reconnectAllowed);
        if (notice.reconnectAllowed) {
          await tester.tap(find.text('Войти'));
          await tester.tap(find.text('Без микрофона'));
        }
      }
      expect(joins, 3);
      expect(listens, 3);
    },
  );
  testWidgets(
    'announces kick text/explanation once and distinguishes other reasons',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
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
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: VoiceDisconnectNoticeView(notice: notice)),
            ),
          );
          expect(find.text(notice.message), findsOneWidget);
          expect(find.text(notice.explanation), findsOneWidget);
          expect(
            tester
                .widget<Semantics>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is Semantics &&
                        widget.properties.liveRegion == true,
                  ),
                )
                .properties
                .liveRegion,
            isTrue,
          );
        }
      } finally {
        semantics.dispose();
      }
    },
  );
}
