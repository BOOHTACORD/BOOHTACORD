import '../../../search_avatar_foreground/component.dart';
import '../../../search_avatar_initials/component.dart';
import '../../../search_date/component.dart';
import '../../../../../widgets/message_timestamp.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceSearchPanelResultHitRenderer
    on WorkspaceWorkspaceSearchPanelStateContext {
  ConstrainedBox renderWorkspaceSearchPanelResultHit(
    SearchMessage message,
    String author,
    GuildMember? member,
  ) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 76),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message:
                '${workspaceConversationLabel(message)} · ${MessageTimestamp.full(message.createdAt)}',
            child: Text(
              '${workspaceConversationLabel(message)} · ${workspaceSearchDate(message.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GcColors.muted,
                fontSize: 12,
                height: 16 / 12,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Row(
              children: [
                AuthenticatedAvatar(
                  state: state,
                  name: author,
                  avatarUrl: member?.avatarUrl,
                  radius: 14,
                  fallbackFontSize: 11,
                  fallbackText: workspaceSearchAvatarInitials(author),
                  fallbackColor: workspaceSearchAvatarForeground(
                    message.authorId,
                  ),
                  backgroundColor: voiceAvatarColor(message.authorId),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: GcColors.text, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          message.messageKind == 'SYSTEM_WELCOME'
              ? SystemWelcomeContent(displayName: author, body: message.body)
              : FormattedMessageBody(
                  body: message.body,
                  color: GcColors.text,
                  fontSize: 14,
                  lineHeight: 20 / 14,
                  searchTerm: workspaceActiveQuery,
                ),
        ],
      ),
    ),
  );
}
