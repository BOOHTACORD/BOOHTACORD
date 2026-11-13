import 'dart:async';

import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../voice_roster_state/app_support.dart';
import '../voice_roster_state/support.dart';

class PendingHistoryApi extends RosterApi {
  final history = Completer<DirectChatMessagePage>(), started = Completer<void>();
  int directReads = 0;
  @override
  Future<DirectChatMessagePage> directMessageHistoryPage(String id, {String? before, String? at}) {
    if (!started.isCompleted) started.complete();
    return history.future;
  }
  @override
  Future<List<DirectConversation>> directMessages() async { directReads++; return []; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('old direct history cannot update state or start new work after socket end', () async {
    final api = PendingHistoryApi(), state = ready(api);
    state.workspace.selectedDirectMessage = const DirectConversation(
        id: 'dialog', participantId: 'other', displayName: 'Other', unreadCount: 0);
    state.realtime.socketAttempt.begin();
    final pending = Future<void>.sync(() => state.realtime.dispatch(
      const RealtimeEvent('old', 'direct_message.message_updated', {
        'direct_message_id': 'dialog', 'message_id': 'message',
      }),
    ));
    await api.started.future.timeout(const Duration(seconds: 5));
    await state.realtime.close();
    api.history.complete(DirectChatMessagePage(messages: [DirectChatMessage(
      id: 'message', directMessageId: 'dialog', authorId: 'other', body: 'synthetic',
      createdAt: DateTime.utc(2026), deleted: false, revision: 1,
    )]));
    await pending;
    expect(state.conversation.directMessageHistory, isEmpty);
    expect(api.directReads, 0);
  });

  test('current direct history still applies and refreshes navigation', () async {
    final api = PendingHistoryApi(), state = ready(api);
    state.workspace.selectedDirectMessage = const DirectConversation(
        id: 'dialog', participantId: 'other', displayName: 'Other', unreadCount: 0);
    state.realtime.socketAttempt.begin();
    final pending = Future<void>.sync(() => state.realtime.dispatch(
      const RealtimeEvent('current', 'direct_message.message_updated', {
        'direct_message_id': 'dialog', 'message_id': 'message',
      }),
    ));
    await api.started.future.timeout(const Duration(seconds: 5));
    api.history.complete(DirectChatMessagePage(messages: [DirectChatMessage(
      id: 'message', directMessageId: 'dialog', authorId: 'other', body: 'synthetic',
      createdAt: DateTime.utc(2026), deleted: false, revision: 1,
    )]));
    await pending;
    expect(state.conversation.directMessageHistory, hasLength(1));
    expect(api.directReads, 1);
  });
}
