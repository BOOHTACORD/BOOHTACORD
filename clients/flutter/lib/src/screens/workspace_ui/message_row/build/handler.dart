import 'sender_metadata/handler.dart';
import 'sender_header/handler.dart';
import '../../confirm_delete/component.dart';
import 'mention_label/handler.dart';
import '../../message_social/component.dart';
import '../../reply_preview/component.dart';
import '../../native_bindings.dart';
import '../../../../widgets/message_timestamp.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMessageRowBuildBinding on WorkspaceMessageRowContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceMessageRowBuild(context);
  }
}

extension WorkspaceMessageRowBuildAction on WorkspaceMessageRowContext {
  Widget executeWorkspaceMessageRowBuild(BuildContext context) {
    observeMessageRender(message, context);
    final compact =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
    final avatarDiameter = compact ? 32.0 : 36.0;
    final member = state.members
        .where((value) => value.id == message.authorId)
        .firstOrNull;
    final authorName = member?.displayName ?? message.authorId;
    if (message.kind == 'SYSTEM_WELCOME') {
      return SystemWelcomeMessage(
        message: message,
        displayName: member?.displayName ?? 'Участник',
        onDelete: state.user?.isAdmin == true
            ? () async {
                if (await workspaceConfirmDelete(context)) {
                  await state.deleteText(message);
                }
              }
            : null,
      );
    }
    final time = MessageTimestamp.short(message.createdAt);
    final gutter = (MediaQuery.textScalerOf(context).scale(10) * 3.6).clamp(
      avatarDiameter,
      double.infinity,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grouped)
          SizedBox(
            width: gutter,
            child: MessageTimestamp(message.createdAt, compact: true),
          )
        else
          SizedBox(
            width: gutter,
            child: Align(
              alignment: Alignment.topLeft,
              child: AuthenticatedAvatar(
                state: state,
                name: authorName,
                avatarUrl: member?.avatarUrl,
                radius: avatarDiameter / 2,
                backgroundColor: GcColors.accent,
              ),
            ),
          ),
        SizedBox(width: compact ? 8 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!grouped)
                renderMessageRowSenderHeader(authorName, time)
              else
                renderMessageRowSenderMetadata(authorName, time),
              if (!grouped) const SizedBox(height: 4),
              if (replyPreview != null && !message.deleted)
                WorkspaceReplyPreview(
                  label: replyPreview!,
                  onTap: onJumpToReply,
                ),
              if (message.deleted)
                const Text(
                  'Сообщение удалено',
                  style: TextStyle(
                    color: GcColors.muted,
                    fontSize: 15,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                FormattedMessageBody(body: message.body, color: GcColors.text),
              DeliveryStatus(
                status: message.sendStatus,
                busy: state.sending,
                retryBlocked: state.conversation.blockedSendRetries.contains(
                  message.clientMessageId,
                ),
                onRetry: onRetry,
                onDiscard: () => state.deleteText(message),
              ),
              if (!message.deleted &&
                  message.sendStatus == null &&
                  message.attachments.isNotEmpty)
                MessageAttachmentList(
                  state: state,
                  parentPath:
                      '/channels/${Uri.encodeComponent(message.channelId)}',
                  attachments: message.attachments,
                ),
              if (message.mentionUserIds.isNotEmpty && !message.deleted)
                renderMessageMentionLabel(),
              if (!message.deleted && message.sendStatus == null)
                MessageSocialControls(
                  transport: state.api.transport,
                  direct: false,
                  conversation: message.channelId,
                  message: message.id,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
