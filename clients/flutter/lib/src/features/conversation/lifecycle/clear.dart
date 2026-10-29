import '../../../services/composer_draft_memory.dart';
import '../../../services/conversation_scroll_memory.dart';
import 'controller.dart';

extension ConversationCleanup on ConversationController {
  void clear() {
    sendObservation.clear();
    cacheGeneration++;
    invalidateSelection();
    ComposerDraftMemory.clear();
    ConversationScrollMemory.clear();
    clearText();
    clearDirect();
    sending = false;
    sendRetryIds.clear();
    blockedSendRetries.clear();
    pendingTextSends.clear();
    pendingDirectSends.clear();
    directSendReceipts.clear();
    lastReadDirectMessageId = null;
    lastReadTextCursor.clear();
    pendingTextReadCursor.clear();
    pendingTextReads.clear();
  }

  void clearText() {
    invalidateSelection();
    messages = const [];
    nextMessageCursor = null;
    olderTextHistoryError = null;
    textHistoryHasLoadedOlderPages = false;
  }

  void clearDirect() {
    invalidateSelection();
    directMessageHistory = const [];
    nextDirectMessageCursor = null;
    olderDirectHistoryError = null;
    lastReadDirectMessageId = null;
  }
}
