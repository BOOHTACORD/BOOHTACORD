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

const _avatarBackgrounds = [
  Color(0xFF17464A),
  Color(0xFF553521),
  Color(0xFF393059),
  Color(0xFF423657),
  Color(0xFF556176),
];
const _avatarForegrounds = [
  Color(0xFFA5F2F0),
  Color(0xFFFFD5A8),
  Color(0xFFE3DCFF),
  Color(0xFFE9CBFF),
  Color(0xFFF4F5FA),
];
final _avatarLetterPattern = RegExp(r'\p{L}', unicode: true);

int _avatarTone(String identity) {
  var hash = 2166136261;
  for (final unit in identity.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0xFFFFFFFF;
  }
  return hash % _avatarBackgrounds.length;
}

String _avatarInitials(String name) {
  final letters = name.runes
      .where((rune) => _avatarLetterPattern.hasMatch(String.fromCharCode(rune)))
      .take(2)
      .map(String.fromCharCode)
      .join();
  return letters.isEmpty ? 'У' : letters.toUpperCase();
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
    final avatarTone = _avatarTone(member.id);
    final isOffline = memberPresence == MemberPresence.offline;
    return Material(
      color: GcColors.sidebar,
      child: InkWell(
        onTap: () => workspaceShowMemberProfile(member),
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AuthenticatedAvatar(
                        state: state,
                        name: member.displayName,
                        avatarUrl: member.avatarUrl,
                        radius: 16,
                        backgroundColor: _avatarBackgrounds[avatarTone],
                        fallbackColor: _avatarForegrounds[avatarTone],
                        fallbackText: _avatarInitials(member.displayName),
                        fallbackFontSize: 13,
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isOffline ? GcColors.sidebar : presence.$2,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isOffline
                                  ? GcColors.muted
                                  : GcColors.sidebar,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        excludeFromSemantics: true,
                        message: member.displayName,
                        child: Text(
                          member.displayName,
                          semanticsLabel: voiceStatus == null
                              ? '${member.displayName}, ${presence.$1}'
                              : '${member.displayName}, ${presence.$1}, в голосовом канале «${voiceStatus.channelName}»${voiceStatus.screenSharing ? ', транслирует экран' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: GcColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 16 / 14,
                          ),
                        ),
                      ),
                      if (voiceStatus case final status?) ...[
                        const SizedBox(height: 2),
                        Tooltip(
                          message: status.screenSharing
                              ? 'Транслирует экран в канале «${status.channelName}»'
                              : 'В голосовом канале «${status.channelName}»',
                          child: Row(
                            children: [
                              Icon(
                                status.screenSharing
                                    ? Icons.desktop_windows_outlined
                                    : Icons.volume_up_outlined,
                                key: ValueKey('member-voice-icon:${member.id}'),
                                size: 12,
                                color: status.screenSharing
                                    ? GcColors.accentText
                                    : GcColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Голосовой канал · ${status.channelName}',
                                  key: ValueKey(
                                    'member-voice-presence:${member.id}',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: status.screenSharing
                                        ? GcColors.accentText
                                        : GcColors.muted,
                                    fontSize: 11,
                                    height: 12 / 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
