import '../../../mention_display_name/component.dart';
import '../../../search_context_message/component.dart';
import '../../../search_date_time/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension SearchMessageContextContextMessagesRenderer
    on WorkspaceSearchMessageContextStateContext {
  Expanded renderSearchMessageContextContextMessages(
    List<WorkspaceSearchContextMessage> messages,
    SearchMessage? target,
    bool isDirect,
  ) => Expanded(
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      itemCount: messages.length,
      separatorBuilder: (_, index) {
        final before = messages[index];
        final after = messages[index + 1];
        return SizedBox(height: before.authorId == after.authorId ? 6 : 18);
      },
      itemBuilder: (context, index) {
        final message = messages[index];
        final authorId = message.authorId;
        final authorName = workspaceMentionDisplayName(
          widget.state,
          authorId,
        ).substring(1);
        final isTarget = message.id == target?.id;
        final createdAt = message.createdAt;
        final body = message.body;
        final deleted = message.deleted;
        final attachments = message.attachments;
        final conversationId = isDirect
            ? widget.state.selectedDirectMessage?.id
            : widget.state.selectedChannel?.id;
        return Container(
          key: isTarget ? workspaceTargetKey : null,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isTarget ? GcColors.selected : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isTarget ? Border.all(color: GcColors.accentText) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$authorName · ${workspaceSearchDateTime(createdAt)}${message.editedAt == null ? '' : ' · изменено'}',
                style: const TextStyle(color: GcColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 5),
              if (deleted)
                const Text(
                  'Сообщение удалено.',
                  style: TextStyle(
                    color: GcColors.muted,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else ...[
                message.messageKind == 'SYSTEM_WELCOME'
                    ? SystemWelcomeContent(displayName: authorName, body: body)
                    : FormattedMessageBody(body: body, color: GcColors.text),
                if (attachments.isNotEmpty && conversationId != null)
                  MessageAttachmentList(
                    messageId: message.id,
                    state: widget.state,
                    parentPath: isDirect
                        ? '/direct-messages/${Uri.encodeComponent(conversationId)}'
                        : '/channels/${Uri.encodeComponent(conversationId)}',
                    attachments: attachments,
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
