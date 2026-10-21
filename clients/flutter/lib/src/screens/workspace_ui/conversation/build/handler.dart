import 'history_list/handler.dart';
import 'composer_region/handler.dart';
import '../../empty_conversation/component.dart';
import '../../error_banner/component.dart';
import '../../header/component.dart';
import '../../header/conversation_actions.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateBuildBinding
    on WorkspaceConversationStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceConversationStateBuild(context);
  }
}

extension WorkspaceConversationStateBuildAction
    on WorkspaceConversationStateContext {
  Widget executeWorkspaceConversationStateBuild(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compact = viewportWidth < GcLayout.mobileBreakpoint;
    final compactComposerActions = viewportWidth <= 720;
    final composerBorderRadius = workspaceReplyTarget == null
        ? const BorderRadius.all(Radius.circular(12))
        : const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          );
    final renderedMessages = widget.state.messages;
    final timeline = messageTimeline(renderedMessages);
    final hasOlderTextCursor = widget.state.nextMessageCursor != null;
    final olderTextHistoryError = widget.state.olderTextHistoryError;
    final historyHeaderCount =
        (hasOlderTextCursor ? 1 : 0) + (olderTextHistoryError == null ? 0 : 1);
    if (workspaceObservedChannelId != widget.channel.id ||
        !identical(workspaceObservedMessages, renderedMessages)) {
      workspaceObservedChannelId = widget.channel.id;
      workspaceObservedMessages = renderedMessages;
      workspaceLatestLayoutConfirmed = false;
      final renderedKeys = renderedMessages
          .map((message) => '${widget.channel.id}:${message.id}')
          .toSet();
      workspaceMessageKeys.removeWhere((key, _) => !renderedKeys.contains(key));
      workspaceScheduleVisibleRead(renderedMessages, correctLatestLayout: true);
    }
    return Column(
      children: [
        WorkspaceHeader(
          icon: Icons.tag_rounded,
          title: widget.channel.name,
          subtitle: widget.channel.description?.trim().isNotEmpty == true
              ? widget.channel.description!.trim()
              : 'Текстовый канал',
          mobileConversationLayout: true,
          onToggleNavigation: widget.onToggleNavigation,
          onOpenMembers: widget.onOpenMembers,
          trailing: ConversationHeaderActions(
            state: widget.state,
            direct: false,
            busy: widget.state.loadingMessages,
            onRefresh: () => widget.state.selectChannel(widget.channel),
          ),
        ),
        if (widget.state.error != null)
          WorkspaceErrorBanner(message: widget.state.error!),
        Expanded(
          child: widget.state.loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : widget.state.messages.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => widget.state.selectChannel(widget.channel),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.sizeOf(context).height * 0.45,
                        ),
                        child: WorkspaceEmptyConversation(
                          channel: widget.channel.name,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => widget.state.selectChannel(widget.channel),
                  child: renderConversationHistoryList(
                    compact,
                    viewportWidth,
                    timeline,
                    historyHeaderCount,
                    hasOlderTextCursor,
                    olderTextHistoryError,
                  ),
                ),
        ),
        renderConversationComposerRegion(
          compact,
          viewportWidth,
          composerBorderRadius,
          compactComposerActions,
        ),
      ],
    );
  }
}
