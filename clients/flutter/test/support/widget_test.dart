import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/features/direct/conversations/support_contact.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/direct_conversation/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/support_contact/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/user_footer/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/composer_draft_memory.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../uiux_2026/capture_support.dart';

const peer = '22222222-2222-4222-8222-222222222222';
const support = DirectConversation(
  id: 'support-pair',
  participantId: peer,
  displayName: 'Local operator',
  unreadCount: 0,
);
const other = DirectConversation(
  id: 'other-pair',
  participantId: 'other-peer',
  displayName: 'Other',
  unreadCount: 0,
);
void main() {
  testWidgets('public support hides the composer until explicit consent', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    state.user = const SessionUser(accountId: 'qa-account', role: 'MEMBER');
    addTearDown(state.dispose);
    state.workspace.supportContact = const SupportContact(
      state: 'available',
      revision: 2,
      accountId: peer,
      mode: 'product',
      noticeVersion: 1,
      consentRequired: true,
      repositoryPublic: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: Scaffold(
          body: WorkspaceDirectConversation(
            state: state,
            conversation: support,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Согласен на публикацию'), findsOneWidget);
    expect(find.textContaining('доступны всем'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'support uses ordinary composer and retains other conversation draft',
    (tester) async {
      ComposerDraftMemory.clear();
      final state = AppState(ApiClient());
      state.user = const SessionUser(accountId: 'qa-account', role: 'MEMBER');
      addTearDown(state.dispose);
      state.workspace.supportContact = const SupportContact(
        state: 'available',
        revision: 1,
        accountId: peer,
      );
      Future<void> show(DirectConversation value) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            home: Scaffold(
              body: WorkspaceDirectConversation(
                state: state,
                conversation: value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      final fields = find.byType(TextField);
      await show(other);
      await tester.enterText(fields, 'Synthetic other draft');
      await show(support);
      expect(
        tester.widget<TextField>(fields).decoration?.hintText,
        'Написать сообщение…',
      );
      expect(find.text(supportPrivacy), findsOneWidget);
      state.workspace.supportChanged = true;
      await show(support);
      expect(
        find.textContaining('Оператор поддержки изменился.'),
        findsOneWidget,
      );
      await tester.enterText(fields, 'Synthetic support draft');
      await show(other);
      expect(
        tester.widget<TextField>(fields).controller!.text,
        'Synthetic other draft',
      );
      await show(support);
      expect(
        tester.widget<TextField>(fields).controller!.text,
        'Synthetic support draft',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('selected busy support paints above the sidebar background', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    state.user = const SessionUser(accountId: 'qa-account', role: 'MEMBER');
    addTearDown(state.dispose);
    state.workspace.supportContact = const SupportContact(
      state: 'available',
      revision: 1,
      accountId: peer,
    );
    state.directMessages = [support];
    state.selectedDirectMessage = support;
    state.workspace.supportOpening = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: Scaffold(
          body: ColoredBox(
            color: GcColors.sidebar,
            child: SupportContactRow(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('support composer stays visible with enlarged text and IME', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    await loadUiuxVisualCaptureFonts();
    final state = AppState(ApiClient());
    state.user = const SessionUser(accountId: 'qa-account', role: 'MEMBER');
    addTearDown(state.dispose);
    state.workspace.supportContact = const SupportContact(
      state: 'available',
      revision: 1,
      accountId: peer,
    );
    const capture = ValueKey('support-ime');
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 220),
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: capture,
          child: Scaffold(
            body: WorkspaceDirectConversation(
              state: state,
              conversation: support,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final composer = find.byType(TextField);
    final rect = tester.getRect(composer);
    expect(rect.bottom, lessThanOrEqualTo(420));
    expect(rect.top, greaterThanOrEqualTo(0));
    await captureUiuxBoundary(
      tester,
      find.byKey(capture),
      fileName: 'support-320-text2-ime.png',
      pixelRatio: 1,
    );
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 393.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'support footer and empty pinned contact at $width text $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 800);
          addTearDown(tester.view.reset);
          await loadUiuxVisualCaptureFonts();
          final state = AppState(ApiClient());
          state.user = const SessionUser(
            accountId: 'qa-account',
            role: 'MEMBER',
          );
          addTearDown(state.dispose);
          state.workspace.supportContact = const SupportContact(
            state: 'available',
            revision: 1,
            accountId: peer,
          );
          const key = ValueKey('support-capture');
          await tester.pumpWidget(
            MaterialApp(
              theme: guildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: Column(
                    children: [
                      SupportContactRow(state: state),
                      const Spacer(),
                      WorkspaceUserFooter(state: state),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Поддержка'), findsOneWidget);
          expect(state.directMessages, isEmpty);
          final button = find.byTooltip('Помощь и обратная связь');
          final size = tester.getSize(button);
          expect(size.width, greaterThanOrEqualTo(44));
          expect(size.height, greaterThanOrEqualTo(44));
          await captureUiuxBoundary(
            tester,
            find.byKey(key),
            fileName: 'support-${width.toInt()}-text$scale.png',
            pixelRatio: 1,
          );
          state.workspace.supportContact = const SupportContact(
            state: 'self',
            revision: 2,
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: SupportContactRow(state: state)),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Поддержка'), findsNothing);
        },
      );
    }
  }
}
