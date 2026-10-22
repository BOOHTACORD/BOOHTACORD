import '../native_bindings.dart';
import '../support_contact/component.dart';

class WorkspaceDirectMessageNavigation extends StatelessWidget {
  const WorkspaceDirectMessageNavigation({
    super.key,
    required this.state,
    this.onSelected,
  });
  final AppState state;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                'ЛИЧНЫЕ СООБЩЕНИЯ',
                style: TextStyle(
                  color: GcColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          PopupMenuButton<DirectCandidate>(
            tooltip: 'Начать диалог',
            onSelected: (candidate) async {
              await state.createDirectConversation(candidate);
              onSelected?.call();
            },
            itemBuilder: (_) => state.directMessageCandidates
                .map(
                  (candidate) => PopupMenuItem(
                    value: candidate,
                    child: Text(candidate.displayName),
                  ),
                )
                .toList(growable: false),
            icon: const Icon(Icons.add_comment_outlined, size: 19),
          ),
        ],
      ),
      SupportContactRow(state: state, onSelected: onSelected),
      for (final conversation in state.directMessages.where(
        (value) => !state.isSupportConversation(value),
      ))
        Material(
          color: Colors.transparent,
          child: ListTile(
            selected: state.selectedDirectMessage?.id == conversation.id,
            dense:
                MediaQuery.sizeOf(context).width >= GcLayout.mobileBreakpoint,
            minTileHeight: 48,
            selectedTileColor: GcColors.selected,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            leading: Builder(
              builder: (context) {
                final member = state.members
                    .where((m) => m.id == conversation.participantId)
                    .firstOrNull;
                final presence = member == null
                    ? MemberPresence.unknown
                    : state.memberPresence(member);
                final label = switch (presence) {
                  MemberPresence.online => 'В сети',
                  MemberPresence.offline => 'Не в сети',
                  MemberPresence.unknown => 'Статус неизвестен',
                };
                return Semantics(
                  label: label,
                  child: Stack(
                    children: [
                      AuthenticatedAvatar(
                        state: state,
                        name: conversation.displayName,
                        avatarUrl: member?.avatarUrl,
                        radius: 18,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (presence) {
                              MemberPresence.online => GcColors.success,
                              MemberPresence.offline => GcColors.muted,
                              MemberPresence.unknown => GcColors.warning,
                            },
                            border: Border.all(
                              color: GcColors.sidebar,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            title: Tooltip(
              message: conversation.displayName,
              child: Text(
                conversation.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: conversation.unreadCount > 0
                ? Badge(label: Text('${conversation.unreadCount}'))
                : null,
            onTap: () async {
              await state.openDirectConversation(conversation);
              onSelected?.call();
            },
          ),
        ),
      if (state.directMessages.isEmpty && !state.supportAvailable)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Диалогов пока нет. Нажмите +, чтобы начать.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
    ],
  );
}
