import '../search_drawer/handler.dart';
import '../../../../../widgets/pinned_screen_dock.dart';
import '../drawer_sidebar/handler.dart';
import '../../../drawer_surface/component.dart';
import '../../../members_panel/component.dart';
import '../../../sidebar/component.dart';
import '../../../workspace_search_panel/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceScreenMobileLayersRenderer on WorkspaceScreenStateContext {
  Stack renderWorkspaceScreenMobileLayers(
    bool searchPanelModal,
    bool pinnedMiniVisible,
    bool showMemberToggle,
    Widget Function() pinnedMiniLayer,
    bool fullScreenSearch,
    BoxConstraints constraints,
  ) => Stack(
    children: [
      Positioned.fill(
        child: PinnedScreenDock(
          content: Stack(
            children: [
              renderWorkspaceScreenDrawerSidebar(
                searchPanelModal,
                pinnedMiniVisible,
                showMemberToggle,
              ),
            ],
          ),
          mini: pinnedMiniVisible ? pinnedMiniLayer() : null,
        ),
      ),
      renderWorkspaceScreenSearchDrawer(searchPanelModal, fullScreenSearch),
      SlidingDrawerLayer(
        visible: workspaceShowMobileSidebar,
        side: SlidingDrawerSide.left,
        width: (constraints.maxWidth - 40).clamp(0.0, 320.0).toDouble(),
        child: HorizontalSwipeRegion(
          onSwipeLeft: workspaceCloseDrawers,
          child: WorkspaceDrawerSurface(
            child: WorkspaceSidebar(
              key: const ValueKey('mobile-sidebar'),
              state: widget.state,
              showVoiceDock: false,
              onChannelSelected: workspaceCloseDrawers,
              onClose: workspaceCloseDrawers,
              onSearch: workspaceToggleSearch,
              searchFocusNode: workspaceSearchTriggerFocus,
            ),
          ),
        ),
      ),
      SlidingDrawerLayer(
        visible: workspaceShowMembersDrawer,
        side: SlidingDrawerSide.right,
        width: (constraints.maxWidth - 40).clamp(0.0, 320.0).toDouble(),
        child: HorizontalSwipeRegion(
          onSwipeRight: workspaceCloseDrawers,
          child: WorkspaceDrawerSurface(
            child: WorkspaceMembersPanel(
              state: widget.state,
              onClose: workspaceCloseDrawers,
            ),
          ),
        ),
      ),
      if (searchPanelModal && !fullScreenSearch)
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: (constraints.maxWidth - 40).clamp(0.0, 320.0).toDouble(),
          child: WorkspaceDrawerSurface(
            debugLabel: 'workspace-search',
            child: WorkspaceWorkspaceSearchPanel(
              key: ValueKey(widget.state.workspace.searchSessionEpoch),
              state: widget.state,
            ),
          ),
        ),
    ],
  );
}
