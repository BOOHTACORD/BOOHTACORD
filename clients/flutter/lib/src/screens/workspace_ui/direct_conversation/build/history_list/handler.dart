import '../message_reply_swipe/handler.dart';
import '../../../older_history_error_row/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';
import '../../../../../services/conversation_scroll_restore.dart';

extension DirectConversationHistoryListRenderer
    on WorkspaceDirectConversationStateContext {
  RefreshIndicator renderDirectConversationHistoryList(
    bool compact,
    int directHistoryHeaderCount,
    bool hasOlderDirectCursor,
    String? olderDirectHistoryError,
  ) {
    final saved = workspacePendingScroll;
    if (saved != null &&
        !workspaceRestoringScroll &&
        !widget.state.loadingDirectMessages) {
      workspacePendingScroll = null;
      workspaceRestoringScroll = true;
      final conversation = widget.conversation.id;
      unawaited(
        restoreConversationScroll(
          scroll: workspaceScroll,
          saved: saved,
          keys: workspaceDirectMessageKeys,
          prefix: conversation,
          ids: widget.state.directMessageHistory.map((e) => e.id).toList(),
          active: () => mounted && widget.conversation.id == conversation,
        ).whenComplete(() {
          workspaceRestoringScroll = false;
        }),
      );
    }
    return RefreshIndicator(
      onRefresh: () => widget.state.openDirectConversation(widget.conversation),
      child: ListView.builder(
        key: const ValueKey('direct-message-messages'),
        controller: workspaceScroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: compact
            ? const EdgeInsets.fromLTRB(12, 16, 12, 8)
            : const EdgeInsets.fromLTRB(24, 20, 24, 12),
        itemCount:
            widget.state.directMessageHistory.length + directHistoryHeaderCount,
        findChildIndexCallback: (key) {
          final messageKey = workspaceDirectMessageKeys.entries
              .where((entry) => identical(entry.value, key))
              .firstOrNull;
          if (messageKey == null) return null;
          final messageId = messageKey.key.substring(
            widget.conversation.id.length + 1,
          );
          final messageIndex = widget.state.directMessageHistory.indexWhere(
            (message) => message.id == messageId,
          );
          if (messageIndex < 0) return null;
          return messageIndex + directHistoryHeaderCount;
        },
        itemBuilder: (context, index) {
          if (hasOlderDirectCursor && index == 0) {
            return Center(
              child: TextButton.icon(
                onPressed: widget.state.loadingOlderDirectMessages
                    ? null
                    : workspaceLoadOlderDirect,
                icon: widget.state.loadingOlderDirectMessages
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.history),
                label: Text(
                  widget.state.loadingOlderDirectMessages
                      ? 'Загружаем…'
                      : 'Загрузить предыдущие сообщения',
                ),
              ),
            );
          }
          final errorRowIndex = hasOlderDirectCursor ? 1 : 0;
          if (olderDirectHistoryError != null && index == errorRowIndex) {
            return WorkspaceOlderHistoryErrorRow(
              message: olderDirectHistoryError,
              loading: widget.state.loadingOlderDirectMessages,
              onRetry: workspaceLoadOlderDirect,
            );
          }
          final messageIndex = index - directHistoryHeaderCount;
          final message = widget.state.directMessageHistory[messageIndex];
          observeMessageRender(message, context);
          final own = message.authorId == widget.state.user?.accountId;
          final key = workspaceDirectMessageKeys.putIfAbsent(
            '${widget.conversation.id}:${message.id}',
            () => GlobalKey(
              debugLabel: '${widget.conversation.id}:${message.id}',
            ),
          );
          return renderDirectConversationMessageReplySwipe(
            key,
            context,
            message,
            own,
          );
        },
      ),
    );
  }
}
