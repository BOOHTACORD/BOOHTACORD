import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateInitStateBinding
    on WorkspaceDirectConversationStateContext {
  @override
  void initState() {
    super.initState();
    executeWorkspaceDirectConversationStateInitState();
  }
}

extension WorkspaceDirectConversationStateInitStateAction
    on WorkspaceDirectConversationStateContext {
  void executeWorkspaceDirectConversationStateInitState() {
    workspaceDraftAccountId = widget.state.user?.accountId;
    workspaceDraftEpoch = ComposerDraftMemory.epoch;
    workspaceController.addListener(workspaceRememberDraft);
    workspaceRestoreDraft(widget.conversation.id);
    workspaceLoadSavedScroll();
    workspaceScroll.addListener(workspaceRememberScrollAfterLayout);
  }
}
