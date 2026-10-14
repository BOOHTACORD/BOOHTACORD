import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceRestoreDraftBinding
    on WorkspaceDirectConversationStateContext {
  @override
  void workspaceRestoreDraft(String conversationId) {
    executeWorkspaceDirectConversationStateWorkspaceRestoreDraft(
      conversationId,
    );
  }
}

extension WorkspaceDirectConversationStateWorkspaceRestoreDraftAction
    on WorkspaceDirectConversationStateContext {
  void executeWorkspaceDirectConversationStateWorkspaceRestoreDraft(
    String conversationId,
  ) {
    workspaceRestoringDraft = true;
    final accountId = workspaceDraftAccountId;
    final draft =
        accountId == null || workspaceDraftEpoch != ComposerDraftMemory.epoch
        ? null
        : ComposerDraftMemory.load<DirectChatMessage>(
            accountId,
            ComposerDraftKind.directMessage,
            conversationId,
          );
    workspaceController.value = TextEditingValue(text: draft?.body ?? '');
    workspacePendingReplyId = draft?.pendingReplyId;
    workspaceReplyTarget =
        draft?.replyTarget ??
        widget.state.directMessageHistory
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
