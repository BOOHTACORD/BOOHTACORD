import '../../conversation/lifecycle/controller.dart';

Future<void> refreshDirectEvent(
  ConversationController conversation, [
  String? messageID,
  bool replace = false,
  bool Function()? socketCurrent,
]) async {
  final current = conversation.selectedDirectMessage;
  final active = conversation.admission(selection: true);
  bool valid() => active() && (socketCurrent?.call() ?? true);
  if (current == null || !valid()) return;
  final page = await conversation.api.directMessageHistoryPage(
    current.id,
    at: messageID,
  );
  if (!valid() || conversation.selectedDirectMessage?.id != current.id) return;
  final byId = {
    if (!replace)
      for (final message in conversation.directMessageHistory)
        message.id: message,
  };
  for (final message in page.messages) {
    final old = byId[message.id];
    if (old == null || message.revision >= old.revision) {
      byId[message.id] = message;
    }
  }
  conversation.acknowledgeMessageIds(
    page.messages.map((m) => m.clientMessageId),
  );
  conversation.directMessageHistory = conversation.withPendingDirect(
    current.id,
    byId.values,
  );
  if (replace) conversation.nextDirectMessageCursor = page.nextCursor;
  conversation.changed();
}
