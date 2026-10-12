import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/direct/conversations/candidate_page.dart';
import 'package:boohtacord_desktop/src/screens/workspace_screen.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/search_message_context/lifecycle/widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationApi extends ApiClient {
  static const peer = DirectConversation(
    id: 'dialog',
    participantId: 'peer',
    displayName: 'Новый участник',
    unreadCount: 0,
  );
  bool opened = false;
  @override
  Future<DirectCandidatePage> directMessageCandidatePage({
    String? after,
  }) async => const DirectCandidatePage(
    items: [DirectCandidate(id: 'peer', displayName: 'Новый участник')],
    nextAfter: null,
  );
  @override
  Future<String> openDirectMessage(String id) async {
    opened = true;
    return peer.id;
  }

  @override
  Future<List<DirectConversation>> directMessages() async =>
      opened ? [peer] : [];
  @override
  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,

    String? at,
  }) async => const DirectChatMessagePage(messages: []);
}

Future<void> shortcut(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final existing in [false, true]) {
    testWidgets(
      'mobile quick jump opens ${existing ? 'existing' : 'new'} DM without reopening navigation',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = NavigationApi()..opened = existing;
        final state = AppState(api);
        addTearDown(state.dispose);
        state.user = const SessionUser(accountId: 'self', role: 'MEMBER');
        state.phase = AppPhase.ready;
        state.topology = const ChannelTopology(revision: 1, categories: []);
        if (existing) {
          state.directMessages = [NavigationApi.peer];
          state.selectedDirectMessage = NavigationApi.peer;
        }
        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: state,
              builder: (_, _) =>
                  WorkspaceScreen(state: state, openNavigationInitially: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await shortcut(tester);
        expect(state.workspacePanel, WorkspacePanel.search);
        await tester.tap(find.byTooltip('Каналы и люди'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('guild-quick-jump-query')),
          'Новый',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('quick-jump-person-peer')));
        await tester.pumpAndSettle();
        expect(state.selectedDirectMessage?.id, NavigationApi.peer.id);
        expect(state.workspacePanel, WorkspacePanel.none);
        expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
        await state.openSearchContext(
          SearchMessage(
            id: 'origin',
            kind: SearchMessageKind.directMessage,
            conversationId: NavigationApi.peer.id,
            authorId: 'peer',
            body: '',
            createdAt: DateTime.utc(2026),
            revision: 1,
          ),
          heading: 'Контекст ответа',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('К последним сообщениям'));
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Закрыть навигацию').hitTestable(),
          findsOneWidget,
        );
        await shortcut(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(state.workspacePanel, WorkspacePanel.none);
        expect(
          find.byTooltip('Закрыть навигацию').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  testWidgets(
    'reply-context Back respects a narrow pane inside a desktop viewport',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = AppState(NavigationApi());
      addTearDown(state.dispose);
      state.searchContextHeading = 'Контекст ответа';
      state.searchContextError = 'Сообщение недоступно.';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              child: SizedBox(
                width: 390,
                child: WorkspaceSearchMessageContext(state: state),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('К последним сообщениям'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
