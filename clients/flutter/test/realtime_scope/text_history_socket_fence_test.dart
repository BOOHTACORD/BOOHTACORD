import 'dart:async';

import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../voice_roster_state/app_support.dart';
import '../voice_roster_state/support.dart';

class PendingTextApi extends RosterApi {
  final history = Completer<ChatMessagePage>(), started = Completer<void>();
  final topologyGate = Completer<ChannelTopology>(),
      topologyStarted = Completer<void>();
  int topologyReads = 0;
  @override
  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) {
    if (!started.isCompleted) started.complete();
    return history.future;
  }

  @override
  Future<ChannelTopology> topology() {
    topologyReads++;
    if (!topologyStarted.isCompleted) topologyStarted.complete();
    return topologyGate.future;
  }
}

ChatMessagePage page() => ChatMessagePage(
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

  test(
    'old text history cannot update state or start new work after socket end',
    () async {
      final api = PendingTextApi(), state = ready(api);
      state.workspace.selectedChannel = const GuildChannel(
        id: 'channel',
        name: 'QA',
        kind: ChannelKind.text,
        admissionClosed: false,
      );
      state.realtime.socketAttempt.begin();
      final pending = Future<void>.sync(
        () => state.realtime.dispatch(
          const RealtimeEvent('old', 'message.updated', {
            'channel_id': 'channel',
            'message_id': 'message',
          }),
        ),
      );
      await api.started.future.timeout(const Duration(seconds: 5));
      await state.realtime.close();
      api.history.complete(page());
      await Future<void>.delayed(Duration.zero);
      final appliedOld = state.conversation.messages.isNotEmpty;
      if (api.topologyReads > 0) {
        api.topologyGate.complete(
          const ChannelTopology(revision: 1, categories: []),
        );
      }
      await pending;
      expect(appliedOld, isFalse);
      expect(state.conversation.loadingMessages, isFalse);
      expect(api.topologyReads, 0);
    },
  );

  test(
    'current text history still applies and starts topology refresh',
    () async {
      final api = PendingTextApi(), state = ready(api);
      state.workspace.selectedChannel = const GuildChannel(
        id: 'channel',
        name: 'QA',
        kind: ChannelKind.text,
        admissionClosed: false,
      );
      state.realtime.socketAttempt.begin();
      final pending = Future<void>.sync(
        () => state.realtime.dispatch(
          const RealtimeEvent('current', 'message.updated', {
            'channel_id': 'channel',
            'message_id': 'message',
          }),
        ),
      );
      await api.started.future.timeout(const Duration(seconds: 5));
      api.history.complete(page());
      await api.topologyStarted.future.timeout(const Duration(seconds: 5));
      expect(state.conversation.messages, hasLength(1));
      api.topologyGate.complete(
        const ChannelTopology(revision: 1, categories: []),
      );
      await pending;
      expect(api.topologyReads, 1);
    },
  );
}
