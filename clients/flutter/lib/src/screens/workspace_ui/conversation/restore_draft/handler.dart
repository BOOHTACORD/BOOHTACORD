import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceRestoreDraftBinding
    on WorkspaceConversationStateContext {
  @override
  void workspaceRestoreDraft(String channelId) {
    executeWorkspaceConversationStateWorkspaceRestoreDraft(channelId);
  }
}

extension WorkspaceConversationStateWorkspaceRestoreDraftAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateWorkspaceRestoreDraft(
    String channelId,
  ) {
    workspaceRestoringDraft = true;
    final accountId = workspaceDraftAccountId;
    final draft =
        accountId == null || workspaceDraftEpoch != ComposerDraftMemory.epoch
        ? null
        : ComposerDraftMemory.load<ChatMessage>(
            accountId,
            ComposerDraftKind.channel,
            channelId,
          );
    workspaceController.value = TextEditingValue(text: draft?.body ?? '');
    workspacePendingReplyId = draft?.pendingReplyId;
    workspaceReplyTarget =
        draft?.replyTarget ??
        widget.state.messages
            .where((m) => m.id == workspacePendingReplyId)
            .firstOrNull;
    workspaceMentionUserIds
      ..clear()
      ..addAll(draft?.mentionUserIds ?? const []);
    workspaceAttachments = draft?.attachments ?? const [];
    workspaceAttachmentsPending = false;
    workspaceRestoringDraft = false;
  }
}
