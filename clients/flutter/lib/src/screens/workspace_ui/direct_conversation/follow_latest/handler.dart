import '../../../../services/conversation_scroll_memory.dart';
import '../../../../features/direct/follow_latest/viewport.dart';

import 'package:flutter/widgets.dart';

import '../lifecycle/context.dart';

extension DirectConversationFollowLatest
    on WorkspaceDirectConversationStateContext {
  bool Function() directHistoryActivity() {
    final pair = widget.conversation.id;
    final account = widget.state.user?.accountId;
    final history = widget.state.directMessageHistory;
    return () =>
        mounted &&
        widget.conversation.id == pair &&
        widget.state.selectedDirectMessage?.id == pair &&
        widget.state.user?.accountId == account &&
        identical(widget.state.directMessageHistory, history) &&
        !widget.state.loadingDirectMessages &&
        !workspaceRestoringScroll &&
        workspacePendingScroll == null &&
        workspaceScrollMemoryEpoch == ConversationScrollMemory.epoch;
  }

  void scheduleDirectFollowLatest() {
    final pair = widget.conversation.id;
    final account = widget.state.user?.accountId;
    final history = widget.state.directMessageHistory;
    final active = directHistoryActivity();
    workspaceTailFollower.observe(
      scope: '$account\u0000$pair',
      ids: history.map((message) => message.id).toList(growable: false),
      scroll: workspaceScroll,
      blocked: account == null || !active(),
      active: active,
    );
  }

  Widget wrapDirectHistoryJump(Widget child) {
    final active = directHistoryActivity();
    return DirectHistoryViewport(
      scroll: workspaceScroll,
      available: active,
      onJump: () => workspaceTailFollower.jumpToLatest(
        scroll: workspaceScroll,
        active: active,
      ),
      child: child,
    );
  }
}
