import '../message_bubble/handler.dart';
import '../../../direct_message_action_menu/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';
import '../../../../../widgets/message_timestamp.dart';

extension DirectConversationMessageReplySwipeRenderer
    on WorkspaceDirectConversationStateContext {
  KeyedSubtree renderDirectConversationMessageReplySwipe(
    GlobalKey<State<StatefulWidget>> key,
    BuildContext context,
    DirectChatMessage message,
    bool own, {
    bool grouped = false,
  }) => KeyedSubtree(
    key: key,
    child: HorizontalSwipeRegion(
      enabled:
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android) &&
          MediaQuery.sizeOf(context).width < 1024 &&
          !message.deleted &&
          message.sendStatus == null,
      canStart: (position, _) => position.dx >= 72,
      onSwipeRight: () => workspaceReplyToDirect(message),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.textScalerOf(context).scale(10) * 3.6,
            child: grouped
                ? MessageTimestamp(message.createdAt, compact: true)
                : Align(
                    alignment: Alignment.topLeft,
                    child: AuthenticatedAvatar(
                      state: widget.state,
                      name: workspaceDirectAuthorName(message.authorId),
                      avatarUrl: own
                          ? widget.state.profile?.avatarUrl
                          : widget.state.members
                                .where((m) => m.id == message.authorId)
                                .firstOrNull
                                ?.avatarUrl,
                      radius: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          renderDirectConversationMessageBubble(own, message, grouped: grouped),
          if (!message.deleted && message.sendStatus == null)
            WorkspaceDirectMessageActionMenu(
              message: message,
              canEdit: own,
              onReply: workspaceReplyToDirect,
              mentionOptions: [
                (
                  widget.conversation.participantId,
                  widget.conversation.displayName,
                ),
              ],
              selfId: widget.state.user?.accountId ?? '',
              onEdit: (body, revision, ids) =>
                  widget.state.editDirectWithResult(
                    message,
                    body,
                    revision,
                    mentionUserIds: ids,
                  ),
              onRefresh: () async {
                final latest = await widget.state.refreshDirectMessageRevision(
                  message,
                );
                return latest == null
                    ? null
                    : (revision: latest.revision, deleted: latest.deleted);
              },
              onDelete: () => widget.state.deleteDirect(message),
            ),
        ],
      ),
    ),
  );
}
