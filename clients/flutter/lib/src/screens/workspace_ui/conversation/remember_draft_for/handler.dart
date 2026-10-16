import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceRememberDraftForBinding
    on WorkspaceConversationStateContext {
  @override
  void workspaceRememberDraftFor(String channelId) {
    executeWorkspaceConversationStateWorkspaceRememberDraftFor(channelId);
  }
}

extension WorkspaceConversationStateWorkspaceRememberDraftForAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateWorkspaceRememberDraftFor(
    String channelId,
  ) {
    final accountId = workspaceDraftAccountId;
    if (workspaceRestoringDraft ||
        accountId == null ||
        workspaceDraftEpoch != ComposerDraftMemory.epoch) {
      return;
    }
    ComposerDraftMemory.save(
      accountId,
      ComposerDraftKind.channel,
      channelId,
      ComposerDraft<ChatMessage>(
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
