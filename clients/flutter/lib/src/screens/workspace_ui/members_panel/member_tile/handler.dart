import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateWorkspaceMemberTileBinding
    on WorkspaceMembersPanelStateContext {
  @override
  Widget workspaceMemberTile(
    BuildContext context,
    GuildMember member,
    MemberPresence memberPresence,
  ) {
    return executeWorkspaceMembersPanelStateWorkspaceMemberTile(
      context,
      member,
      memberPresence,
    );
  }
}

extension WorkspaceMembersPanelStateWorkspaceMemberTileAction
    on WorkspaceMembersPanelStateContext {
  Widget executeWorkspaceMembersPanelStateWorkspaceMemberTile(
    BuildContext context,
    GuildMember member,
    MemberPresence memberPresence,
  ) {
    final presence = switch (memberPresence) {
      MemberPresence.online => ('В сети', GcColors.success),
      MemberPresence.offline => ('Не в сети', GcColors.muted),
      MemberPresence.unknown => ('Статус неизвестен', GcColors.warning),
    };
    return Material(
      color: GcColors.sidebar,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        minTileHeight: 48,
        onTap: () => workspaceShowMemberProfile(member),
        leading: Stack(
          children: [
            AuthenticatedAvatar(
              state: state,
              name: member.displayName,
              avatarUrl: member.avatarUrl,
              radius: 20,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: presence.$2,
                  shape: BoxShape.circle,
                  border: Border.all(color: GcColors.sidebar, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Tooltip(
          excludeFromSemantics: true,
          message: member.displayName,
          child: Text(
            member.displayName,
            semanticsLabel: '${member.displayName}, ${presence.$1}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
