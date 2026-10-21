import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateWorkspaceHandleHardwareKeyBinding
    on WorkspaceMembersPanelStateContext {
  @override
  bool workspaceHandleHardwareKey(KeyEvent event) {
    return executeWorkspaceMembersPanelStateWorkspaceHandleHardwareKey(event);
  }
}

extension WorkspaceMembersPanelStateWorkspaceHandleHardwareKeyAction
    on WorkspaceMembersPanelStateContext {
  bool executeWorkspaceMembersPanelStateWorkspaceHandleHardwareKey(
    KeyEvent event,
  ) {
    if (workspaceProfileDialogContext == null &&
        workspaceProfileMemberId != null &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      workspaceCloseMemberProfile();
      return true;
    }
    return false;
  }
}
