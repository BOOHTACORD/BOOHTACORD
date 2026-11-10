import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../voice_roster_state/support.dart';
import 'support.dart';

void main() {
  testWidgets(
    'unavailable is not an empty roster and retry requests the shared socket',
    (tester) async {
      final harness = RosterHarness();
      addTearDown(harness.owner.dispose);
      harness.owner
        ..phase = VoiceRosterPhase.unavailable
        ..voiceRosterError = 'bounded failure';
      await showPreview(tester, harness);
      expect(find.text('Не удалось обновить состав комнаты.'), findsOneWidget);
      expect(find.text('Пока никого нет.'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('retry-voice-roster')));
      await tester.pump();
      expect(harness.retries, 1);
    },
  );

  testWidgets(
    'stale empty snapshot is labelled as historical and remains retryable',
    (tester) async {
      final harness = RosterHarness();
      addTearDown(harness.owner.dispose);
      harness.owner
        ..phase = VoiceRosterPhase.stale
        ..voiceRosters = [
          VoiceRoomRoster(channelId: 'voice-1', participants: []),
        ];
      await showPreview(tester, harness);
      expect(find.text('Последний состав был пустым.'), findsOneWidget);
      expect(find.text('Пока никого нет.'), findsNothing);
      final button = tester.widget<TextButton>(
        find.byKey(const ValueKey('retry-voice-roster')),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('expired session requests login and does not offer retry', (
    tester,
  ) async {
    final harness = RosterHarness();
    addTearDown(harness.owner.dispose);
    harness.owner.phase = VoiceRosterPhase.sessionExpired;
    await showPreview(tester, harness);
    expect(find.text('Сессия завершена. Войдите снова.'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-voice-roster')), findsNothing);
    expect(find.text('Пока никого нет.'), findsNothing);
  });
}
