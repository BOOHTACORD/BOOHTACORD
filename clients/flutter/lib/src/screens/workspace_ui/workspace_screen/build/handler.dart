import '../layout_policy/derive.dart';
import 'editing_shell/handler.dart';
import 'back_guard/handler.dart';
import 'search_overlay/handler.dart';
import 'pinned_layer/handler.dart';
import 'mobile_layers/handler.dart';
import 'swipe_navigation/handler.dart';
import 'desktop_layers/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateBuildBinding on WorkspaceScreenStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceScreenStateBuild(context);
  }
}

extension WorkspaceScreenStateBuildAction on WorkspaceScreenStateContext {
  Widget executeWorkspaceScreenStateBuild(BuildContext context) => Scaffold(
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    floatingActionButton: AnimatedBuilder(
      animation: widget.state.voice,
      builder: (context, _) =>
          VoiceShortcutStatus(message: widget.state.voiceShortcutStatus),
    ),
    body: SafeArea(
      top:
          !widget.maintenanceBannerVisible &&
          defaultTargetPlatform != TargetPlatform.macOS &&
          defaultTargetPlatform != TargetPlatform.windows,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = workspaceLayout(constraints.maxWidth);
          final compact = layout.compact;
          final medium = layout.medium;
          final wide = layout.wide;
          final searchPanelActive = layout.searchPanelActive;
          final searchPanelModal = layout.searchPanelModal;
          final fullScreenSearch = layout.fullScreenSearch;
          final modalOverlayActive = layout.modalOverlayActive;
          final showPermanentMembers = layout.showPermanentMembers;
          final showMemberToggle = layout.showMemberToggle;
          final activeVoiceChannel = widget.state.voiceChannel;
          final pinnedMiniVisible = screenViewerMiniPlayerVisible(
            selectedScreenIdentity: workspaceMiniScreenIdentity,
            activeVoiceChannelId: activeVoiceChannel?.id,
            selectedChannelId: widget.state.selectedChannel?.id,
            directMessageOpen: widget.state.selectedDirectMessage != null,
            workspacePanelOpen:
                widget.state.workspacePanel != WorkspacePanel.none,
          );
          Widget pinnedMiniLayer() => renderWorkspaceScreenPinnedLayer(
            compact,
            constraints,
            modalOverlayActive,
            pinnedMiniVisible,
            activeVoiceChannel,
          );
          final content = compact
              ? renderWorkspaceScreenMobileLayers(
                  searchPanelModal,
                  pinnedMiniVisible,
                  showMemberToggle,
                  pinnedMiniLayer,
                  fullScreenSearch,
                  constraints,
                )
              : renderWorkspaceScreenDesktopLayers(
                  modalOverlayActive,
                  wide,
                  medium,
                  pinnedMiniVisible,
                  showMemberToggle,
                  showPermanentMembers,
                  searchPanelActive,
                  searchPanelModal,
                  pinnedMiniLayer,
                  fullScreenSearch,
                  constraints,
                );
          final shellContent = renderWorkspaceEditingShell(content, compact);
          final mobileGestures =
              compact &&
              (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android);
          final drawerSwipeEnabled =
              mobileGestures &&
              widget.state.workspacePanel == WorkspacePanel.none &&
              !workspaceShowMobileSidebar &&
              !workspaceShowMembersDrawer &&
              !searchPanelModal;
          final swipeContent = mobileGestures
              ? renderWorkspaceScreenSwipeNavigation(
                  drawerSwipeEnabled,
                  showMemberToggle,
                  shellContent,
                )
              : shellContent;
          final presentedContent = fullScreenSearch
              ? renderWorkspaceScreenSearchOverlay(swipeContent)
              : swipeContent;
          return renderWorkspaceScreenBackGuard(presentedContent);
        },
      ),
    ),
  );
}
