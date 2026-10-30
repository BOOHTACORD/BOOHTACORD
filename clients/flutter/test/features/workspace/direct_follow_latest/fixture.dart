import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/direct_conversation/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/composer_draft_memory.dart';
import 'package:boohtacord_desktop/src/services/conversation_scroll_memory.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture.dart';

const pair = DirectConversation(
  id: 'owned-pair',
  participantId: 'peer',
  displayName: 'Peer',
  unreadCount: 0,
);
DirectChatMessage message(int index, {String dmId = 'owned-pair'}) =>
    DirectChatMessage(
      id: 'message-$index',
      directMessageId: dmId,
      authorId: 'peer',
      body: 'Incoming fixture $index',
      createdAt: DateTime.utc(2026, 10, 30).add(Duration(minutes: index)),
      deleted: false,
      revision: 1,
    );

class ReadApi extends ApiClient {
  @override
  Future<void> advanceDirectMessageReadCursor(
    String pairId,
    String messageId,
  ) async {}
}

class Harness {
  Harness(this.tester);
  final WidgetTester tester;
  final state = AppState(ReadApi());
  final list = find.byKey(const ValueKey('direct-message-messages'));
  ScrollController get scroll => tester.widget<ListView>(list).controller!;
  Future<void> mount({double textScale = 1}) async {
    await loadTailFonts();
    ComposerDraftMemory.clear();
    ConversationScrollMemory.clear();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    state.user = const SessionUser(accountId: 'reader', role: 'MEMBER');
    state.selectedDirectMessage = pair;
    state.directMessages = [pair];
    state.directMessageHistory = List.generate(40, message);
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('qa609-surface'),
          child: Scaffold(
            body: AnimatedBuilder(
              animation: state,
              builder: (_, _) =>
                  WorkspaceDirectConversation(state: state, conversation: pair),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> latest() async {
    for (var i = 0; i < 12 && scroll.position.extentAfter > 1; i++) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    expect(scroll.position.extentAfter, lessThanOrEqualTo(1));
  }

  Future<void> append() async {
    state.directMessageHistory = [...state.directMessageHistory, message(40)];
    state.notifyListeners();
    await tester.pumpAndSettle();
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    tester.view.reset();
    ComposerDraftMemory.clear();
    ConversationScrollMemory.clear();
  }
}
