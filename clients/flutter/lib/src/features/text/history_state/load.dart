import '../../conversation/lifecycle/controller.dart';

extension ConversationLoadChannelHistory on ConversationController {
  Future<void> loadChannelHistory(
    GuildChannel channel, {
    bool Function()? socketCurrent,
  }) async {
    invalidateSelection();
    final active = admission(selection: true);
    bool current() => active() && (socketCurrent?.call() ?? true);
    if (!current()) return;
    final loadSequence = ++textHistoryLoadSequence;
    messages = const [];
    nextMessageCursor = null;
    olderTextHistoryError = null;
    textHistoryHasLoadedOlderPages = false;
    loadingMessages = false;
    error = null;
    changed();
    if (channel.kind == ChannelKind.text) {
      loadingMessages = true;
      changed();
      try {
        final page = await api.messagePage(channel.id);
        if (!current()) return;
        if (textHistoryLoadSequence == loadSequence &&
            selectedChannel?.id == channel.id) {
          acknowledgeMessageIds(
            page.messages.map((message) => message.clientMessageId),
          );
          messages = withPendingText(channel.id, page.messages);
          nextMessageCursor = page.nextCursor;
        }
      } catch (cause) {
        if (!current()) return;
        if (textHistoryLoadSequence == loadSequence &&
            selectedChannel?.id == channel.id) {
          error = formatError(cause);
        }
      } finally {
        if (active()) {
          if (textHistoryLoadSequence == loadSequence) {
            loadingMessages = false;
            changed();
          }
        }
      }
    }
  }
}
