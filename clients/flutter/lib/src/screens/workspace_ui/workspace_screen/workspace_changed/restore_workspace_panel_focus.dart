import '../../native_bindings.dart';

import '../lifecycle/context.dart';

extension RestoreWorkspacePanelFocusAction on WorkspaceScreenStateContext {
  void restoreWorkspacePanelFocus() {
    final previous = workspaceLastWorkspacePanel;
    final current = widget.state.workspacePanel;
    workspaceLastWorkspacePanel = current;
    const returnFocusPanels = {
      WorkspacePanel.profile,
      WorkspacePanel.audio,
      WorkspacePanel.admin,
    };
    if (previous == WorkspacePanel.none &&
        returnFocusPanels.contains(current)) {
      workspaceWorkspacePanelReturnFocus = FocusManager.instance.primaryFocus;
    }
    if (returnFocusPanels.contains(previous) &&
        current == WorkspacePanel.none) {
      final returnFocus = workspaceWorkspacePanelReturnFocus;
      workspaceWorkspacePanelReturnFocus = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && returnFocus?.canRequestFocus == true) {
          returnFocus!.requestFocus();
        }
      });
    }
    if ((previous == WorkspacePanel.search ||
            previous == WorkspacePanel.searchContext) &&
        current == WorkspacePanel.none &&
        widget.state.workspace.restoreSearchLauncherFocus) {
      final compact =
          MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
      if (compact) {
        workspaceMutateView(() => workspaceShowMobileSidebar = true);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && workspaceSearchTriggerFocus.canRequestFocus) {
          workspaceSearchTriggerFocus.requestFocus();
        }
      });
    }
  }
}
