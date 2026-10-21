import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateWorkspaceCloseMemberProfileBinding
    on WorkspaceMembersPanelStateContext {
  @override
  void workspaceCloseMemberProfile() {
    executeWorkspaceMembersPanelStateWorkspaceCloseMemberProfile();
  }
}

extension WorkspaceMembersPanelStateWorkspaceCloseMemberProfileAction
    on WorkspaceMembersPanelStateContext {
  void executeWorkspaceMembersPanelStateWorkspaceCloseMemberProfile() {
    final dialog = workspaceProfileDialogContext;
    if (dialog != null && dialog.mounted) Navigator.of(dialog).pop();
  }
}
