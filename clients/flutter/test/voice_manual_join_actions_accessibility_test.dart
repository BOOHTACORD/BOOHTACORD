import 'dart:ui' show SemanticsAction;

import 'package:boohtacord_desktop/src/features/voice/disconnect_notice/model.dart';
import 'package:boohtacord_desktop/src/widgets/voice_disconnect/join_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual voice join actions expose named button semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var joinCalls = 0;
    var listenCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceManualJoinActions(
            joining: false,
            leaving: false,
            admissionClosed: false,
            onJoin: () => joinCalls++,
            onListen: () => listenCalls++,
          ),
        ),
      ),
    );

    final join = find.widgetWithText(FilledButton, 'Подключиться к голосу');
    final listen = find.widgetWithText(
      OutlinedButton,
      'Подключиться без микрофона',
    );
    for (final button in [join, listen]) {
      final data = tester.getSemantics(button).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, isNotEmpty);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    }

    await tester.tap(join);
    await tester.tap(listen);
    expect(joinCalls, 1);
    expect(listenCalls, 1);
    semantics.dispose();
  });

  testWidgets('joining state disables both voice entry actions accessibly', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceManualJoinActions(
            joining: true,
            leaving: false,
            admissionClosed: false,
            onJoin: () {},
            onListen: () {},
          ),
        ),
      ),
    );

    final join = find.widgetWithText(FilledButton, 'Подключаемся…');
    final listen = find.widgetWithText(
      OutlinedButton,
      'Подключиться без микрофона',
    );
    for (final button in [join, listen]) {
      expect(
        tester.getSemantics(button).getSemanticsData().hasAction(
          SemanticsAction.tap,
        ),
        isFalse,
      );
    }
    semantics.dispose();
  });

  testWidgets('closed and non-reconnectable voice states stay non-actionable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    for (final (admissionClosed, notice, expectedLabel) in [
      (true, null, 'Вход временно закрыт'),
      (
        false,
        VoiceDisconnectNotice('BANNED', 'server'),
        'Подключиться к голосу',
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceManualJoinActions(
              joining: false,
              leaving: false,
              admissionClosed: admissionClosed,
              notice: notice,
              onJoin: () {},
              onListen: () {},
            ),
          ),
        ),
      );

      final join = find.widgetWithText(FilledButton, expectedLabel);
      final listen = find.widgetWithText(
        OutlinedButton,
        'Подключиться без микрофона',
      );
      for (final button in [join, listen]) {
        expect(
          tester.getSemantics(button).getSemanticsData().hasAction(
            SemanticsAction.tap,
          ),
          isFalse,
        );
      }
    }
    semantics.dispose();
  });
}
