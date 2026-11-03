import 'channel_contents/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceChannelRowStateBuildBinding on WorkspaceChannelRowStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceChannelRowStateBuild(context);
  }
}

extension WorkspaceChannelRowStateBuildAction
    on WorkspaceChannelRowStateContext {
  Widget executeWorkspaceChannelRowStateBuild(BuildContext context) {
    final state = widget.state;
    final channel = widget.channel;
    final selected = widget.selected;
    final voiceConnected = widget.voiceConnected;
    final canManage = canDeleteChannel(state, channel);
    return MouseRegion(
      onEnter: (_) => workspaceMutateView(() => workspaceHovered = true),
      onExit: (_) => workspaceMutateView(() => workspaceHovered = false),
      child: FocusableActionDetector(
        key: ValueKey(
          widget.favoriteShortcut
              ? 'workspace-channel-focus:${channel.id}:favorite'
              : 'workspace-channel-focus:${channel.id}',
        ),
        enabled: canManage,
        onShowHoverHighlight: (value) =>
            workspaceMutateView(() => workspaceHovered = value),
        onShowFocusHighlight: (value) =>
            workspaceMutateView(() => workspaceFocused = value),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (value) =>
              workspaceMutateView(() => workspaceFocused = value),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: selected ? GcColors.selected : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              child: InkWell(
                onTap: widget.onTap,
                onSecondaryTap: canManage
                    ? () => deleteTopologyTarget(context, state, channel)
                    : null,
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  key: ValueKey(
                    widget.favoriteShortcut
                        ? 'workspace-channel-row:${channel.id}:favorite'
                        : 'workspace-channel-row:${channel.id}',
                  ),
                  height:
                      MediaQuery.sizeOf(context).width <
                          GcLayout.mobileBreakpoint
                      ? GcLayout.touchTargetSize
                      : GcLayout.channelRowHeight,
                  child: renderChannelRowChannelContents(
                    voiceConnected,
                    channel,
                    selected,
                    state,
                    showFavoriteButton:
                        widget.onFavoriteChanged != null &&
                        (widget.favorite ||
                            workspaceHovered ||
                            workspaceFocused ||
                            Theme.of(context).platform ==
                                TargetPlatform.android ||
                            Theme.of(context).platform == TargetPlatform.iOS),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
