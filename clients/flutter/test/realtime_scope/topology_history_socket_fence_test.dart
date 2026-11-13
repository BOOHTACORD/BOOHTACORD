import 'dart:async';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../voice_roster_state/app_support.dart';
import '../voice_roster_state/support.dart';

class TopologyHistoryApi extends RosterApi {
  final started = Completer<void>();
  final history = Completer<ChatMessagePage>();
  @override
  Future<ChannelTopology> topology() async => const ChannelTopology(
    revision: 1,
    categories: [
      ChannelCategory(
        id: 'category',
        name: 'QA',
        channels: [
          GuildChannel(
            id: 'channel',
            name: 'QA',
            kind: ChannelKind.text,
            admissionClosed: false,
          ),
        ],
      ),
    ],
  );
  @override
  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) {
    if (!started.isCompleted) started.complete();
    return history.future;
  }
}

class MultipleHistoryApi extends TopologyHistoryApi {
  final requests = <Completer<ChatMessagePage>>[];
  final secondStarted = Completer<void>();
  @override
  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) {
    final request = Completer<ChatMessagePage>();
    requests.add(request);
    if (requests.length == 1) started.complete();
    if (requests.length == 2) secondStarted.complete();
    return request.future;
  }
}

ChatMessagePage historyPage() => ChatMessagePage(
  messages: [
    ChatMessage(
      id: 'message',
      channelId: 'channel',
      authorId: 'other',
      body: 'synthetic',
      createdAt: DateTime.utc(2026),
      deleted: false,
      revision: 1,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final realtime in [true, false]) {
    test(
      realtime
          ? 'socket end fences history started by realtime topology'
          : 'socket end preserves independently started topology history',
      () async {
        final api = TopologyHistoryApi(), state = ready(api);
        state.realtime.socketAttempt.begin();
        final pending = state.workspace.refreshTopology(strict: realtime);
        await api.started.future.timeout(const Duration(seconds: 5));
        await state.realtime.close();
        api.history.complete(historyPage());
        await pending;
        expect(state.conversation.messages.length, realtime ? 0 : 1);
        expect(state.conversation.loadingMessages, isFalse);
      },
    );
  }
  test(
    'old topology history cannot overwrite a newer manual selection',
    () async {
      final api = MultipleHistoryApi(), state = ready(api);
      state.realtime.socketAttempt.begin();
      final old = state.workspace.refreshTopology(strict: true);
      await api.started.future.timeout(const Duration(seconds: 5));
      await state.realtime.close();
      final fresh = state.workspace.selectChannel(
        state.workspace.selectedChannel!,
      );
      await api.secondStarted.future.timeout(const Duration(seconds: 5));
      api.requests[1].complete(historyPage());
      await fresh;
      api.requests[0].complete(const ChatMessagePage(messages: []));
      await old;
      expect(state.conversation.messages, hasLength(1));
      expect(state.conversation.loadingMessages, isFalse);
    },
  );
}
