import '../lifecycle/widget.dart';
import '../../native_bindings.dart';
import '../../../../services/conversation_scroll_memory.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateDidUpdateWidgetBinding
    on WorkspaceConversationStateContext {
  @override
  void didUpdateWidget(covariant WorkspaceConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    executeWorkspaceConversationStateDidUpdateWidget(oldWidget);
  }
}

extension WorkspaceConversationStateDidUpdateWidgetAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateDidUpdateWidget(
    WorkspaceConversation oldWidget,
  ) {
    if (oldWidget.channel.id != widget.channel.id) {
      workspaceRememberDraftFor(oldWidget.channel.id);
    }
    final currentAccountId = widget.state.user?.accountId;
    if (workspaceDraftEpoch != ComposerDraftMemory.epoch) {
      workspaceDraftEpoch = ComposerDraftMemory.epoch;
      workspaceDraftAccountId = currentAccountId;
      workspaceRestoreDraft(widget.channel.id);
    } else if (currentAccountId != workspaceDraftAccountId) {
      if (workspaceDraftAccountId != null) {
        workspaceRememberDraftFor(oldWidget.channel.id);
      }
      workspaceDraftAccountId = currentAccountId;
      workspaceRestoreDraft(widget.channel.id);
    }
    if (workspaceScrollMemoryEpoch != ConversationScrollMemory.epoch ||
        oldWidget.channel.id != widget.channel.id) {
      workspaceScrollMemoryEpoch = ConversationScrollMemory.epoch;
      workspacePendingScroll = currentAccountId == null
          ? null
          : ConversationScrollMemory.load(currentAccountId, widget.channel.id);
      workspaceFollowLatest = workspacePendingScroll?.followLatest ?? true;
      if (workspacePendingScroll != null) {
        workspaceScheduleVisibleRead(widget.state.messages);
      }
    }
    if (oldWidget.channel.id != widget.channel.id) {
      workspaceFollowLatest = workspacePendingScroll?.followLatest ?? true;
      workspaceLatestLayoutConfirmed = false;
      workspaceRestoreDraft(widget.channel.id);
      workspaceObservedChannelId = null;
      workspaceObservedMessages = null;
    }
  }
}
