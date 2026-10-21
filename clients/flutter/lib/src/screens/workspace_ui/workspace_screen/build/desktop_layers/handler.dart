import '../workspace_panels/handler.dart';
import '../../../drawer_scrim/component.dart';
import '../../../drawer_surface/component.dart';
import '../../../members_panel/component.dart';
import '../../../workspace_search_panel/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceScreenDesktopLayersRenderer on WorkspaceScreenStateContext {
  Stack renderWorkspaceScreenDesktopLayers(
    bool modalOverlayActive,
    bool wide,
    bool medium,
    bool pinnedMiniVisible,
    bool showMemberToggle,
    bool showPermanentMembers,
    bool searchPanelActive,
    bool searchPanelModal,
    Widget Function() pinnedMiniLayer,
    bool fullScreenSearch,
    BoxConstraints constraints,
  ) => Stack(
    children: [
      renderWorkspaceScreenWorkspacePanels(
        modalOverlayActive,
        wide,
        medium,
        pinnedMiniVisible,
        showMemberToggle,
        showPermanentMembers,
        searchPanelActive,
        searchPanelModal,
        pinnedMiniLayer,
      ),
      if (workspaceShowMembersDrawer || (searchPanelModal && !fullScreenSearch))
        Positioned.fill(
          child: WorkspaceDrawerScrim(onTap: workspaceCloseScrim),
        ),
      if (workspaceShowMembersDrawer)
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: (constraints.maxWidth - 32).clamp(0.0, 320.0).toDouble(),
          child: WorkspaceDrawerSurface(
            child: WorkspaceMembersPanel(
              state: widget.state,
              onClose: workspaceCloseDrawers,
            ),
          ),
        ),
      if (searchPanelModal && !fullScreenSearch)
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: (constraints.maxWidth - 32).clamp(0.0, 320.0).toDouble(),
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
