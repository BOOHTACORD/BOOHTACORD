import '../../../drawer_scrim/component.dart';
import '../../../drawer_surface/component.dart';
import '../../../workspace_search_panel/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderWorkspaceScreenSearchOverlayAction
    on WorkspaceScreenStateContext {
  Stack renderWorkspaceScreenSearchOverlay(Widget swipeContent) => Stack(
    children: [
      Positioned.fill(
        child: ExcludeFocus(
          excluding: true,
          child: ExcludeSemantics(excluding: true, child: swipeContent),
        ),
      ),
      Positioned.fill(child: WorkspaceDrawerScrim(onTap: workspaceCloseScrim)),
      Positioned.fill(
        child: KeyedSubtree(
          key: const ValueKey('workspace-search-overlay'),
          child: WorkspaceDrawerSurface(
            debugLabel: 'workspace-search',
            child: WorkspaceWorkspaceSearchPanel(
              key: ValueKey(widget.state.workspace.searchSessionEpoch),
              state: widget.state,
            ),
          ),
        ),
      ),
    ],
  );
}
