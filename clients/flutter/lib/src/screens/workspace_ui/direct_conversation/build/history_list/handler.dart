import '../message_reply_swipe/handler.dart';
import '../../../older_history_error_row/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';
import '../../../../../services/conversation_scroll_restore.dart';
import '../../../../../services/message_presentation.dart';
import '../../../history_date_divider/component.dart';

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
          if (key is! ValueKey<String> ||
              !key.value.startsWith('direct-row:${widget.conversation.id}:'))
            return null;
          final messageId = key.value.substring(
            'direct-row:${widget.conversation.id}:'.length,
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
          final previous = messageIndex == 0
              ? null
              : widget.state.directMessageHistory[messageIndex - 1];
          if (workspaceUnreadStartId == null &&
              workspaceInitialUnreadCount > 0 &&
              !widget.state.loadingDirectMessages) {
            final history = widget.state.directMessageHistory;
            workspaceUnreadStartId =
                history[(history.length - workspaceInitialUnreadCount).clamp(
                      0,
                      history.length - 1,
                    )]
                    .id;
          }
          final startsUnread = message.id == workspaceUnreadStartId;
          final grouped = canGroupConversationMessage(
            previousAuthor: previous?.authorId,
            author: message.authorId,
            previousDate: previous?.createdAt,
            date: message.createdAt,
            boundary:
                startsUnread ||
                previous == null ||
                previous.deleted ||
                message.deleted ||
                previous.replyToId != null ||
                message.replyToId != null ||
                previous.sendStatus != null ||
                message.sendStatus != null,
          );
          observeMessageRender(message, context);
          final own = message.authorId == widget.state.user?.accountId;
          final key = workspaceDirectMessageKeys.putIfAbsent(
            '${widget.conversation.id}:${message.id}',
            () => GlobalKey(
              debugLabel: '${widget.conversation.id}:${message.id}',
            ),
          );
          final row = renderDirectConversationMessageReplySwipe(
            key,
            context,
            message,
            own,
            grouped: grouped,
          );
          return Column(
            key: ValueKey('direct-row:${widget.conversation.id}:${message.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (previous == null ||
                  !sameConversationDay(previous.createdAt, message.createdAt))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: WorkspaceHistoryDateDivider(
                    label: conversationDateLabel(message.createdAt),
                  ),
                ),
              if (startsUnread)
                const WorkspaceHistoryDateDivider(label: 'Новые сообщения'),
              Padding(
                padding: EdgeInsets.only(top: grouped ? 4 : 12),
                child: row,
              ),
            ],
          );
        },
      ),
    );
  }
}
