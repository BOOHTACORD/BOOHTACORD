import '../../native_bindings.dart';
import '../../../../services/conversation_scroll_memory.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceOnScrollBinding
    on WorkspaceConversationStateContext {
  @override
  void workspaceOnScroll() {
    executeWorkspaceConversationStateWorkspaceOnScroll();
  }
}

extension WorkspaceConversationStateWorkspaceOnScrollAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateWorkspaceOnScroll() {
    if (!workspaceScroll.hasClients) return;
    workspaceFollowLatest = workspaceScroll.position.extentAfter <= 48;
    workspaceRememberScrollPosition();
    final channel = widget.channel.id;
    final epoch = workspaceScrollMemoryEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.channel.id == channel &&
          epoch == ConversationScrollMemory.epoch) {
        workspaceRememberScrollPosition();
      }
    });
    workspaceScheduleVisibleRead(widget.state.messages);
  }
}
