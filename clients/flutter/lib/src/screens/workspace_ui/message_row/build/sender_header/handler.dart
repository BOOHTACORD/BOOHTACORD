import '../../../message_action_menu/component.dart';
import '../../../native_bindings.dart';
import '../../../../../widgets/message_timestamp.dart';
import '../../lifecycle/context.dart';

extension MessageRowSenderHeaderRenderer on WorkspaceMessageRowContext {
  Row renderMessageRowSenderHeader(String authorName, String time) => Row(
    children: [
      Flexible(
        child: Text(
          authorName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(child: MessageTimestamp(message.createdAt)),
      if (!message.deleted && message.sendStatus == null)
        WorkspaceMessageActionMenu(
          message: message,
          canEdit: message.authorId == state.user?.accountId,
          canDelete:
              message.authorId == state.user?.accountId ||
              state.user?.isAdmin == true,
          onReply: onReply,
          mentionOptions: [
            for (final member in state.members) (member.id, member.displayName),
          ],
          selfId: state.user?.accountId ?? '',
          onEdit: (body, revision, ids) => state.editTextWithResult(
            message,
            body,
            revision,
            mentionUserIds: ids,
          ),
          onRefresh: () async {
            final latest = await state.refreshTextMessageRevision(message);
            return latest == null
                ? null
                : (revision: latest.revision, deleted: latest.deleted);
          },
          onDelete: () => state.deleteText(message),
        ),
    ],
  );
}
