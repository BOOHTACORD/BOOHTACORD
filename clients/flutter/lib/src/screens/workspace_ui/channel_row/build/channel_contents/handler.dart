import '../../../channel_state_badge/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension ChannelRowChannelContentsRenderer on WorkspaceChannelRowStateContext {
  Row renderChannelRowChannelContents(
    bool voiceConnected,
    GuildChannel channel,
    bool selected,
    AppState state, {
    required bool showFavoriteButton,
  }) => Row(
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
      if (showFavoriteButton)
        IconButton(
          key: ValueKey('workspace-channel-favorite:${channel.id}'),
          tooltip:
              '${widget.favorite ? 'Убрать из избранного' : 'Добавить в избранное'}: ${channel.name}',
          onPressed: () => widget.onFavoriteChanged?.call(!widget.favorite),
          visualDensity: _isTouchPlatform(context)
              ? VisualDensity.standard
              : VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(
            width: _isTouchPlatform(context) ? 44 : 32,
            height: _isTouchPlatform(context) ? 44 : 32,
          ),
          icon: Icon(
            widget.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color: widget.favorite ? GcColors.accent : GcColors.muted,
          ),
        ),
      if (widget.showObjectMenu)
        TopologyObjectMenu(
          state: state,
          target: channel,
          visible: workspaceShowObjectMenu,
        ),
    ],
  );

  bool _isTouchPlatform(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.android ||
      Theme.of(context).platform == TargetPlatform.iOS;
}
