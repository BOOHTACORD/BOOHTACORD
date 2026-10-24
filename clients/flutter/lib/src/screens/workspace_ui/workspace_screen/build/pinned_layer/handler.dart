import '../../../pinned_screen_mini_player/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderWorkspaceScreenPinnedLayerAction
    on WorkspaceScreenStateContext {
  Widget renderWorkspaceScreenPinnedLayer(
    bool compact,
    BoxConstraints constraints,
    bool modalOverlayActive,
    bool pinnedMiniVisible,
    GuildChannel? activeVoiceChannel,
  ) {
    final mini = SizedBox(
      key: workspacePinnedMiniKey,
      width: (constraints.maxWidth - (compact ? 24 : 32))
          .clamp(0.0, 360.0)
          .toDouble(),
      child: ExcludeFocus(
        excluding: workspaceShowMobileSidebar || modalOverlayActive,
        child: ExcludeSemantics(
          excluding: workspaceShowMobileSidebar || modalOverlayActive,
          child: WorkspacePinnedScreenMiniPlayer(
            state: widget.state,
            identity: workspaceMiniScreenIdentity!,
            selectedIdentity: workspaceMiniScreenIdentity,
            pinnedMiniVisible: pinnedMiniVisible,
            fullscreenSelection: workspaceFullscreenScreenSelection,
            onReturnToVoice: () =>
                unawaited(widget.state.selectChannel(activeVoiceChannel!)),
            onStopWatching: workspaceStopWatchingPinnedScreen,
            onFullscreenSelectionChanged: workspaceSetFullscreenScreenSelection,
          ),
        ),
      ),
    );
    return mini;
  }
}
