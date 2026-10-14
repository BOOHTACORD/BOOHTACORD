import '../lifecycle/widget.dart';
import '../../native_bindings.dart';
import '../../../../services/conversation_scroll_memory.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateDidUpdateWidgetBinding
    on WorkspaceDirectConversationStateContext {
  @override
  void didUpdateWidget(covariant WorkspaceDirectConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    executeWorkspaceDirectConversationStateDidUpdateWidget(oldWidget);
  }
}

extension WorkspaceDirectConversationStateDidUpdateWidgetAction
    on WorkspaceDirectConversationStateContext {
  void executeWorkspaceDirectConversationStateDidUpdateWidget(
    WorkspaceDirectConversation oldWidget,
  ) {
    if (oldWidget.conversation.id != widget.conversation.id) {
      workspaceRememberDraftFor(oldWidget.conversation.id);
    }
    final currentAccountId = widget.state.user?.accountId;
    if (workspaceDraftEpoch != ComposerDraftMemory.epoch) {
      workspaceDraftEpoch = ComposerDraftMemory.epoch;
      workspaceDraftAccountId = currentAccountId;
      workspaceRestoreDraft(widget.conversation.id);
    } else if (currentAccountId != workspaceDraftAccountId) {
      if (workspaceDraftAccountId != null) {
        workspaceRememberDraftFor(oldWidget.conversation.id);
      }
      workspaceDraftAccountId = currentAccountId;
      workspaceRestoreDraft(widget.conversation.id);
    }
    if (oldWidget.conversation.id != widget.conversation.id) {
      workspaceRestoreDraft(widget.conversation.id);
    }
    if (workspaceScrollMemoryEpoch != ConversationScrollMemory.epoch ||
        oldWidget.conversation.id != widget.conversation.id)
      workspaceLoadSavedScroll();
  }
}
