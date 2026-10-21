import 'history_list/handler.dart';
import 'composer_region/handler.dart';
import '../../error_banner/component.dart';
import '../../header/component.dart';
import '../../header/conversation_actions.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateBuildBinding
    on WorkspaceDirectConversationStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceDirectConversationStateBuild(context);
  }
}

extension WorkspaceDirectConversationStateBuildAction
    on WorkspaceDirectConversationStateContext {
  Widget executeWorkspaceDirectConversationStateBuild(BuildContext context) {
    if (!widget.state.loadingDirectMessages &&
        widget.state.directMessageHistory.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.state.markSelectedDirectMessageRead();
      });
    }
    final renderedMessageKeys = widget.state.directMessageHistory
        .map((message) => '${widget.conversation.id}:${message.id}')
        .toSet();
    workspaceDirectMessageKeys.removeWhere(
      (key, _) => !renderedMessageKeys.contains(key),
    );
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compact = viewportWidth < GcLayout.mobileBreakpoint;
    final compactComposerActions = viewportWidth <= 720;
    final hasOlderDirectCursor = widget.state.nextDirectMessageCursor != null;
    final olderDirectHistoryError = widget.state.olderDirectHistoryError;
    final directHistoryHeaderCount =
        (hasOlderDirectCursor ? 1 : 0) +
        (olderDirectHistoryError == null ? 0 : 1);
    final composerBorderRadius = workspaceReplyTarget == null
        ? const BorderRadius.all(Radius.circular(12))
        : const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          );
    return Column(
      children: [
        WorkspaceHeader(
          icon: Icons.person_outline,
          title: widget.conversation.displayName,
          subtitle: 'Личный диалог',
          mobileConversationLayout: true,
          onToggleNavigation: widget.onToggleNavigation,
          trailing: ConversationHeaderActions(
            state: widget.state,
            direct: true,
            busy: widget.state.loadingDirectMessages,
            onRefresh: () =>
                widget.state.openDirectConversation(widget.conversation),
          ),
        ),
        if (widget.state.error != null)
          WorkspaceErrorBanner(message: widget.state.error!),
        Expanded(
          child: widget.state.loadingDirectMessages
              ? const Center(child: CircularProgressIndicator())
              : widget.state.directMessageHistory.isEmpty
              ? RefreshIndicator(
                  onRefresh: () =>
                      widget.state.openDirectConversation(widget.conversation),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.45,
                        child: Center(
                          child: Text(
                            'Начните диалог с ${widget.conversation.displayName}',
                            style: const TextStyle(color: GcColors.muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : renderDirectConversationHistoryList(
                  compact,
                  directHistoryHeaderCount,
                  hasOlderDirectCursor,
                  olderDirectHistoryError,
                ),
        ),
        renderDirectConversationComposerRegion(
          compact,
          composerBorderRadius,
          compactComposerActions,
        ),
      ],
    );
  }
}
