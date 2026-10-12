import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/direct_conversation/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/composer_draft_memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('two direct conversations retain independent unsent drafts', (
    tester,
  ) async {
    ComposerDraftMemory.clear();
    final state = AppState(ApiClient());
    state.user = const SessionUser(accountId: 'qa-account', role: 'MEMBER');
    addTearDown(state.dispose);
    const b = DirectConversation(
      id: 'qa-dm-b',
      participantId: 'qa-peer-b',
      displayName: 'Peer B',
      unreadCount: 0,
    );
    const c = DirectConversation(
      id: 'qa-dm-c',
      participantId: 'qa-peer-c',
      displayName: 'Peer C',
      unreadCount: 0,
    );
    final composer = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Написать сообщение…',
    );
    String draft() => tester.widget<TextField>(composer).controller!.text;
    Future<void> show(DirectConversation conversation) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceDirectConversation(
              state: state,
              conversation: conversation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await show(b);
    await tester.enterText(composer, 'Unsent B');
    await show(c);
    expect(draft(), isEmpty);
    await tester.enterText(composer, 'Unsent C');
    await show(b);
    expect(draft(), 'Unsent B');
    await show(c);
    expect(draft(), 'Unsent C');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
