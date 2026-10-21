import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateDisposeBinding
    on WorkspaceMembersPanelStateContext {
  @override
  void dispose() {
    executeWorkspaceMembersPanelStateDispose();
    super.dispose();
  }
}

extension WorkspaceMembersPanelStateDisposeAction
    on WorkspaceMembersPanelStateContext {
  void executeWorkspaceMembersPanelStateDispose() {
    HardwareKeyboard.instance.removeHandler(workspaceHandleHardwareKey);
    for (final focus in workspaceProfileFocusNodes.values) {
      focus.dispose();
    }
  }
}
