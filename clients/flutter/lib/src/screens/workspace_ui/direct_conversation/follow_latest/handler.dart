import '../../../../services/conversation_scroll_memory.dart';
import '../lifecycle/context.dart';

extension DirectConversationFollowLatest
    on WorkspaceDirectConversationStateContext {
  void scheduleDirectFollowLatest() {
    final pair = widget.conversation.id;
    final account = widget.state.user?.accountId;
    final history = widget.state.directMessageHistory;
    bool active() =>
        mounted &&
        widget.conversation.id == pair &&
        widget.state.selectedDirectMessage?.id == pair &&
        widget.state.user?.accountId == account &&
        identical(widget.state.directMessageHistory, history) &&
        !widget.state.loadingDirectMessages &&
        !workspaceRestoringScroll &&
        workspacePendingScroll == null &&
        workspaceScrollMemoryEpoch == ConversationScrollMemory.epoch;
    workspaceTailFollower.observe(
      scope: '$account\u0000$pair',
      ids: history.map((message) => message.id).toList(growable: false),
      scroll: workspaceScroll,
      blocked: account == null || !active(),
      active: active,
    );
  }
}
