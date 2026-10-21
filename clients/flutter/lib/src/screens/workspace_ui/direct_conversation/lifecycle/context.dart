import '../../native_bindings.dart';
import '../../../../services/conversation_scroll_memory.dart';
import '../../../../services/conversation_scroll_restore.dart';

import 'widget.dart';

abstract class WorkspaceDirectConversationStateContext
    extends State<WorkspaceDirectConversation> {
  int workspaceInitialUnreadCount = 0;
  String? workspaceUnreadStartId;
  final workspaceController = TextEditingController();
  final workspaceComposerFocus = FocusNode();
  final workspaceAttachmentComposerKey =
      GlobalKey<MessageAttachmentComposerState>();
  final workspaceScroll = ScrollController();
  final Map<String, GlobalKey> workspaceDirectMessageKeys = {};
  int workspaceScrollMemoryEpoch = 0;
  ConversationScrollPosition? workspacePendingScroll;
  bool workspaceRestoringScroll = false;
  void workspaceRememberScroll() {
    final account = workspaceDraftAccountId;
    if (account == null ||
        !workspaceScroll.hasClients ||
        workspaceRestoringScroll ||
        workspacePendingScroll != null) {
      return;
    }
    final anchor = captureConversationAnchor(
      workspaceDirectMessageKeys,
      widget.conversation.id,
    );
    ConversationScrollMemory.save(
      accountId: account,
      channelId: 'dm:${widget.conversation.id}',
      offset: workspaceScroll.position.pixels,
      followLatest: workspaceScroll.position.extentAfter < 24,
      epoch: workspaceScrollMemoryEpoch,
      userInitiated:
          workspaceScroll.position.userScrollDirection != ScrollDirection.idle,
      anchorId: anchor?.id,
      anchorOffset: anchor?.offset ?? 0,
    );
  }

  void workspaceRememberScrollAfterLayout() {
    workspaceRememberScroll();
    final conversation = widget.conversation.id;
    final epoch = workspaceScrollMemoryEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.conversation.id == conversation &&
          epoch == ConversationScrollMemory.epoch) {
        workspaceRememberScroll();
      }
    });
  }

  void workspaceLoadSavedScroll() {
    workspaceScrollMemoryEpoch = ConversationScrollMemory.epoch;
    final account = workspaceDraftAccountId;
    workspacePendingScroll = account == null
        ? null
        : ConversationScrollMemory.load(
            account,
            'dm:${widget.conversation.id}',
          );
  }

  DirectChatMessage? workspaceReplyTarget;
  String? workspacePendingReplyId;
  final Set<String> workspaceMentionUserIds = {};
  List<MessageAttachment> workspaceAttachments = const [];
  bool workspaceAttachmentsPending = false;
  String? workspaceDraftAccountId;
  int workspaceDraftEpoch = 0;
  bool workspaceRestoringDraft = false;
  void workspaceRememberDraft();
  void workspaceRememberDraftFor(String conversationId);
  void workspaceRestoreDraft(String conversationId);
  Future<void> workspacePasteFromClipboard();
  Future<void> workspacePickMentions();
  Future<void> workspacePickEmoji();
  void workspaceInsertEmoji(String emoji);
  Future<void> workspaceLoadOlderDirect();
  List<({GlobalKey key, double top})> workspaceVisibleDirectMessageAnchors();
  Future<void> workspaceSend();
  Future<void> workspaceRetry(DirectChatMessage message);
  String workspaceDirectAuthorName(String accountId);
  String? workspaceDirectReplyLabel(DirectChatMessage message);
  void workspaceJumpToDirectReply(DirectChatMessage message);
  void workspaceReplyToDirect(DirectChatMessage message);
  void workspaceMutateView(VoidCallback action) => setState(action);
}
