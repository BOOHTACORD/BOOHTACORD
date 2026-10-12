import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/screens/guild_quick_jump/component.dart';
import 'package:boohtacord_desktop/src/features/direct/conversations/candidate_page.dart';

import 'support.dart';

void main() {
  testWidgets(
    'actual narrow panel loads authorized people and navigates with Enter',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = JumpHarness();
      h.api.directs = const [
        DirectConversation(
          id: 'dm-new',
          participantId: 'new',
          displayName: 'New member',
          unreadCount: 0,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GuildQuickJumpPanel(createOwner: () => h.owner)),
        ),
      );
      h.api.pending.single.complete(
        const DirectCandidatePage(
          items: [DirectCandidate(id: 'new', displayName: 'New member')],
          nextAfter: null,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New member'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('guild-quick-jump-query')),
        'new',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(h.openedDirect?.id, 'dm-new');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('distinguishes guild candidates from existing DM peers', (
    tester,
  ) async {
    final h = JumpHarness();
    h.directs = const [
      DirectConversation(
        id: 'existing',
        participantId: 'known',
        displayName: 'Собеседник',
        unreadCount: 0,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GuildQuickJumpPanel(createOwner: () => h.owner)),
      ),
    );
    h.api.pending.single.complete(
      const DirectCandidatePage(
        items: [
          DirectCandidate(id: 'known', displayName: 'Собеседник'),
          DirectCandidate(id: 'new', displayName: 'Новый участник'),
        ],
        nextAfter: null,
      ),
    );
    await tester.pumpAndSettle();
    final candidate = find.byKey(const ValueKey('quick-jump-person-new'));
    final existing = find.byKey(const ValueKey('quick-jump-person-known'));
    expect(
      find.descendant(of: candidate, matching: find.text('Участник гильдии')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: existing, matching: find.text('Личное сообщение')),
      findsOneWidget,
    );
    expect(find.text('Собеседник'), findsOneWidget);
  });
  testWidgets('IME composing Enter does not open a dialog', (tester) async {
    final h = JumpHarness();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GuildQuickJumpPanel(createOwner: () => h.owner)),
      ),
    );
    h.api.pending.single.complete(
      const DirectCandidatePage(
        items: [DirectCandidate(id: 'new', displayName: 'New member')],
        nextAfter: null,
      ),
    );
    await tester.pumpAndSettle();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'New',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.api.creates, 0);
    expect(tester.takeException(), isNull);
  });
}
