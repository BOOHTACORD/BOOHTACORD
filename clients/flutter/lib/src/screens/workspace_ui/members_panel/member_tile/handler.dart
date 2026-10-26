import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';
import '../voice_presence.dart';

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
    final voiceStatus = guildMemberVoiceStatus(state, member.id);
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
        minTileHeight: voiceStatus == null ? 48 : 64,
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
            semanticsLabel: voiceStatus == null
                ? '${member.displayName}, ${presence.$1}'
                : '${member.displayName}, ${presence.$1}, в голосовом канале «${voiceStatus.channelName}»${voiceStatus.screenSharing ? ', транслирует экран' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        subtitle: voiceStatus == null
            ? null
            : Text(
                voiceStatus.channelName,
                key: ValueKey('member-voice-presence:${member.id}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GcColors.textSecondary,
                  fontSize: 12,
                ),
              ),
        trailing: voiceStatus == null
            ? null
            : Tooltip(
                message: voiceStatus.screenSharing
                    ? 'Транслирует экран в канале «${voiceStatus.channelName}»'
                    : 'В голосовом канале «${voiceStatus.channelName}»',
                child: Icon(
                  voiceStatus.screenSharing
                      ? Icons.desktop_windows_outlined
                      : Icons.volume_up_outlined,
                  key: ValueKey('member-voice-icon:${member.id}'),
                  size: 18,
                  color: voiceStatus.screenSharing
                      ? GcColors.accentText
                      : GcColors.muted,
                ),
              ),
      ),
    );
  }
}
