import '../../../mention_display_name/component.dart';
import '../../../reply_preview/component.dart';
import '../../../native_bindings.dart';
import '../../../message_social/component.dart';
import '../../lifecycle/context.dart';
import '../../../../../widgets/message_timestamp.dart';

extension DirectConversationMessageBubbleRenderer
    on WorkspaceDirectConversationStateContext {
  Flexible renderDirectConversationMessageBubble(
    bool own,
    DirectChatMessage message, {
    bool grouped = false,
  }) => Flexible(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: own
            ? GcColors.selected.withValues(alpha: .3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!grouped)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  own
                      ? '${workspaceDirectAuthorName(message.authorId)} (вы)'
                      : workspaceDirectAuthorName(message.authorId),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: own ? GcColors.accentText : GcColors.text,
                  ),
                ),
                MessageTimestamp(message.createdAt),
              ],
            ),
          if (workspaceDirectReplyLabel(message) case final label?)
            WorkspaceReplyPreview(
              label: label,
              onTap: () => workspaceJumpToDirectReply(message),
            ),
          if (message.deleted)
            const Text(
              'Сообщение удалено',
              style: TextStyle(
                color: GcColors.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            FormattedMessageBody(
              body: message.body,
              color: GcColors.text,
              fontSize: 14,
              lineHeight: 1.4,
            ),
          DeliveryStatus(
            status: message.sendStatus,
            busy: widget.state.sending,
            retryBlocked: widget.state.conversation.blockedSendRetries.contains(
              message.clientMessageId,
            ),
            onRetry: () => workspaceRetry(message),
            onDiscard: () => widget.state.deleteDirect(message),
          ),
          if (!message.deleted &&
              message.sendStatus == null &&
              message.attachments.isNotEmpty)
            MessageAttachmentList(
              messageId: message.id,
              state: widget.state,
              parentPath:
                  '/direct-messages/${Uri.encodeComponent(message.directMessageId)}',
              attachments: message.attachments,
            ),
          if (message.mentionUserIds.isNotEmpty && !message.deleted) ...[
            const SizedBox(height: 5),
            Text(
              'Упомянуты: ${message.mentionUserIds.map((id) => workspaceMentionDisplayName(widget.state, id)).join(' ')}',
              style: const TextStyle(color: GcColors.muted, fontSize: 11),
            ),
          ],
          if (!message.deleted && message.sendStatus == null)
            MessageSocialControls(
              transport: widget.state.api.transport,
              direct: true,
              conversation: message.directMessageId,
              message: message.id,
            ),
        ],
      ),
    ),
  );
}
