import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateDisposeBinding
    on WorkspaceDirectConversationStateContext {
  @override
  void dispose() {
    executeWorkspaceDirectConversationStateDispose();
    super.dispose();
  }
}

extension WorkspaceDirectConversationStateDisposeAction
    on WorkspaceDirectConversationStateContext {
  void executeWorkspaceDirectConversationStateDispose() {
    workspaceRememberDraft();
    workspaceRememberScroll();
    workspaceScroll.removeListener(workspaceRememberScroll);
    workspaceController.removeListener(workspaceRememberDraft);
    workspaceController.dispose();
    workspaceComposerFocus.dispose();
    workspaceScroll.dispose();
  }
}
