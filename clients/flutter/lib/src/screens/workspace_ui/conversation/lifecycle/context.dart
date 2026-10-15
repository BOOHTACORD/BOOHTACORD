import '../../native_bindings.dart';
import '../../../../services/conversation_scroll_memory.dart';
import '../../../../services/conversation_scroll_restore.dart';

import 'widget.dart';

abstract class WorkspaceConversationStateContext
    extends State<WorkspaceConversation>
    with WidgetsBindingObserver {
  final workspaceController = TextEditingController();
  final workspaceComposerFocus = FocusNode();
  final workspaceAttachmentComposerKey =
      GlobalKey<MessageAttachmentComposerState>();
  final workspaceScroll = ScrollController();
  final Map<String, GlobalKey> workspaceMessageKeys = {};
  final Set<String> workspaceMentionUserIds = {};
  List<MessageAttachment> workspaceAttachments = const [];
  bool workspaceAttachmentsPending = false;
  ChatMessage? workspaceReplyTarget;
  String? workspacePendingReplyId;
  bool workspaceFollowLatest = true;
  double? workspaceRestoreScrollOffset;
  ConversationScrollPosition? workspacePendingScroll;
  bool workspaceRestoringScroll = false;
  int workspaceScrollMemoryEpoch = 0;
  bool workspaceLatestLayoutConfirmed = false;
  String? workspaceObservedChannelId;
  List<ChatMessage>? workspaceObservedMessages;
  String? workspaceDraftAccountId;
  int workspaceDraftEpoch = 0;
  bool workspaceRestoringDraft = false;
  void workspaceRememberDraft();
  void workspaceRememberScrollPosition() {
    if (!workspaceScroll.hasClients ||
        workspaceRestoringScroll ||
        workspacePendingScroll != null) {
      return;
    }
    final accountId = workspaceDraftAccountId;
    if (accountId == null) return;
    final anchor = captureConversationAnchor(
      workspaceMessageKeys,
      widget.channel.id,
    );
    ConversationScrollMemory.save(
      accountId: accountId,
      channelId: widget.channel.id,
      offset: workspaceScroll.position.pixels,
      followLatest: workspaceFollowLatest,
      epoch: workspaceScrollMemoryEpoch,
      userInitiated:
          workspaceScroll.position.userScrollDirection != ScrollDirection.idle,
      anchorId: anchor?.id,
      anchorOffset: anchor?.offset ?? 0,
    );
  }

  void workspaceRestoreDraft(String channelId);
  void workspaceRememberDraftFor(String channelId);
  void workspaceOnScroll();
  void workspaceScheduleVisibleRead(
    List<ChatMessage> renderedMessages, {
    bool correctLatestLayout = false,
  });
  Future<void> workspacePasteFromClipboard();
  Future<void> workspacePickMentions();
  Future<void> workspacePickEmoji();
  void workspaceInsertEmoji(String emoji);
  Future<void> workspaceSend();
  Future<void> workspaceRetry(ChatMessage message);
  void workspaceReplyTo(ChatMessage message);
  Future<void> workspaceLoadOlder();
  List<({GlobalKey key, double top})> workspaceVisibleMessageAnchors();
  Future<void> workspaceJumpToReply(ChatMessage message);
  String? workspaceReplyPreview(ChatMessage message);
  void workspaceMutateView(VoidCallback action) => setState(action);
}
