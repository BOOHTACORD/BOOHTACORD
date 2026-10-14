import '../../native_bindings.dart';
import '../../../../services/conversation_scroll_memory.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateInitStateBinding
    on WorkspaceConversationStateContext {
  @override
  void initState() {
    super.initState();
    executeWorkspaceConversationStateInitState();
  }
}

extension WorkspaceConversationStateInitStateAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateInitState() {
    workspaceDraftAccountId = widget.state.user?.accountId;
    workspaceDraftEpoch = ComposerDraftMemory.epoch;
    workspaceScrollMemoryEpoch = ConversationScrollMemory.epoch;
    final accountId = workspaceDraftAccountId;
    final savedScroll = accountId == null
        ? null
        : ConversationScrollMemory.load(accountId, widget.channel.id);
    if (savedScroll != null) {
      workspacePendingScroll = savedScroll;
      workspaceFollowLatest = savedScroll.followLatest;
      if (!savedScroll.followLatest) {
        workspaceRestoreScrollOffset = null;
      }
    }
    workspaceController.addListener(workspaceRememberDraft);
    workspaceRestoreDraft(widget.channel.id);
    WidgetsBinding.instance.addObserver(this);
    workspaceScroll.addListener(workspaceOnScroll);
  }
}
