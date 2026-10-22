import '../../conversation/lifecycle/controller.dart';

extension ConversationRefreshSelectedTextHistory on ConversationController {
  Future<void> refreshSelectedTextHistory({
    bool strict = false,
    String? at,
    bool replace = false,
  }) async {
    final active = admission(selection: true);
    if (!active()) return;
    final channel = selectedChannel;
    if (channel == null || channel.kind != ChannelKind.text) return;

    final loadSequence = ++textHistoryLoadSequence;
    loadingMessages = true;
    changed();
    try {
      final page = await api.messagePage(channel.id, at: at);
      if (!active()) return;
      if (textHistoryLoadSequence != loadSequence ||
          selectedChannel?.id != channel.id) {
        return;
      }

      final byId = {
        if (!replace)
          for (final message in messages) message.id: message,
      };
      for (final message in page.messages) {
        final existing = byId[message.id];
        if (existing == null || message.revision >= existing.revision) {
          byId[message.id] = message;
        }
      }
      acknowledgeMessageIds(
        page.messages.map((message) => message.clientMessageId),
      );
      messages = withPendingText(channel.id, byId.values);
      if (replace) textHistoryHasLoadedOlderPages = false;
      if (!textHistoryHasLoadedOlderPages) {
        nextMessageCursor = page.nextCursor;
      }
      error = null;
    } catch (cause) {
      if (strict) rethrow;
      if (!active()) return;
      if (textHistoryLoadSequence == loadSequence &&
          selectedChannel?.id == channel.id) {
        error = formatError(cause);
      }
    } finally {
      if (active()) {
        if (textHistoryLoadSequence == loadSequence &&
            selectedChannel?.id == channel.id) {
          loadingMessages = false;
          changed();
        }
      }
    }
  }
}
