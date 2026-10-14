import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceRememberDraftForBinding
    on WorkspaceDirectConversationStateContext {
  @override
  void workspaceRememberDraftFor(String conversationId) {
    executeWorkspaceDirectConversationStateWorkspaceRememberDraftFor(
      conversationId,
    );
  }
}

extension WorkspaceDirectConversationStateWorkspaceRememberDraftForAction
    on WorkspaceDirectConversationStateContext {
  void executeWorkspaceDirectConversationStateWorkspaceRememberDraftFor(
    String conversationId,
  ) {
    final accountId = workspaceDraftAccountId;
    if (workspaceRestoringDraft ||
        accountId == null ||
        workspaceDraftEpoch != ComposerDraftMemory.epoch) {
      return;
    }
    ComposerDraftMemory.save(
      accountId,
      ComposerDraftKind.directMessage,
      conversationId,
      ComposerDraft<DirectChatMessage>(
        body: workspaceController.text,
        replyTarget: workspaceReplyTarget,
        pendingReplyId: workspaceReplyTarget == null
            ? workspacePendingReplyId
            : null,
        attachments: workspaceAttachments,
        mentionUserIds: workspaceMentionUserIds.toList(growable: false),
      ),
    );
  }
}
