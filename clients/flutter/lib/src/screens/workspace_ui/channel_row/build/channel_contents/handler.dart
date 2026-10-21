import '../../../channel_state_badge/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension ChannelRowChannelContentsRenderer on WorkspaceChannelRowStateContext {
  Row renderChannelRowChannelContents(
    bool voiceConnected,
    GuildChannel channel,
    bool selected,
    int? voiceParticipantCount,
    AppState state,
  ) => Row(
    children: [
      if (voiceConnected)
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: GcColors.success,
            borderRadius: BorderRadius.circular(3),
          ),
        )
      else
        const SizedBox(width: 3),
      const SizedBox(width: 9),
      Icon(
        channel.kind == ChannelKind.text
            ? Icons.tag_rounded
            : Icons.volume_up_outlined,
        size: 20,
        color: voiceConnected ? GcColors.success : GcColors.muted,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Tooltip(
          message: channel.name,
          child: Text(
            channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected || voiceConnected
                  ? GcColors.text
                  : GcColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ),
      if (channel.kind == ChannelKind.text && channel.unreadCount > 0)
        WorkspaceChannelStateBadge(
          label: '${channel.unreadCount}',
          semanticLabel: 'Непрочитанных сообщений: ${channel.unreadCount}',
        ),
      if (channel.kind == ChannelKind.text && channel.mentionCount > 0)
        WorkspaceChannelStateBadge(
          label: '@${channel.mentionCount}',
          semanticLabel: 'Упоминаний: ${channel.mentionCount}',
        ),
      if (channel.admissionClosed)
        const Padding(
          padding: EdgeInsets.only(right: 10),
          child: Icon(Icons.lock_outline, size: 16, color: GcColors.warning),
        ),
      if (voiceParticipantCount != null && voiceParticipantCount > 0)
        Padding(
          padding: const EdgeInsets.only(right: 9),
          child: Tooltip(
            message: 'Участников в голосовом канале: $voiceParticipantCount',
            child: Semantics(
              label: 'Участников в голосовом канале: $voiceParticipantCount',
              child: Text(
                '$voiceParticipantCount',
                style: const TextStyle(
                  color: GcColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      TopologyObjectMenu(
        state: state,
        target: channel,
        visible: workspaceShowObjectMenu,
      ),
    ],
  );
}
