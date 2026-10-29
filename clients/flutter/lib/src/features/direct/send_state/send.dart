import '../../conversation/lifecycle/controller.dart';
import '../../conversation/delivery/recovery.dart';
import 'delivery.dart';
import 'hydrate.dart';

extension ConversationSendDirect on ConversationController {
  Future<bool> sendDirect(
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<MessageAttachment> attachments = const [],
  }) async {
    final active = admission(selection: false);
    if (!active()) return false;
    final conversation = selectedDirectMessage;
    final trimmed = body.trim();
    if (conversation == null ||
        sending ||
        trimmed.isEmpty && attachments.isEmpty ||
        trimmed.runes.length > 8000) {
      return false;
    }
    final mentions = mentionUserIds.take(100).toSet().toList();
    final attachmentIds = attachments.map((item) => item.id).toList();
    final retryKey = sendRetryKey(
      'dm',
      conversation.id,
      trimmed,
      replyToId,
      mentions,
      attachmentIds,
    );
    final clientMessageId = sendRetryIds.putIfAbsent(retryKey, uuid.v4);
    final retry = pendingDirectSends.containsKey(clientMessageId);
    if (blockedSendRetries.contains(clientMessageId)) return false;
    final pending =
        pendingDirectSends[clientMessageId] ??
        DirectChatMessage(
          id: 'optimistic:$clientMessageId',
          directMessageId: conversation.id,
          authorId: user?.accountId ?? '',
          body: trimmed,
          createdAt: DateTime.now(),
          deleted: false,
          revision: 0,
          clientMessageId: clientMessageId,
          mentionUserIds: mentions,
          replyToId: replyToId,
          attachments: attachments,
        );
    pendingDirectSends[clientMessageId] = pending.withSendStatus(
      MessageSendStatus.sending,
    );
    if (selectedDirectMessage?.id == conversation.id) {
      directMessageHistory = withPendingDirect(
        conversation.id,
        directMessageHistory,
      );
    }
    sending = true;
    error = null;
    changed();
    final action = sendObservation.begin(clientMessageId);
    try {
      var message = await action.run(
        () => deliverDirect(pending, retry, active),
      );
      if (!active()) return false;
      if (pending.attachments.isNotEmpty) {
        message = newestDirectMessage(pending, message);
      }
      sendObservation.accepted(clientMessageId, message);
      sendRetryIds.remove(retryKey);
      pendingDirectSends.remove(clientMessageId);
      directSendReceipts.remove(clientMessageId);
      if (isReady() && selectedDirectMessage?.id == conversation.id) {
        directMessageHistory = [
          ...directMessageHistory.where(
            (value) =>
                value.id != message.id &&
                value.clientMessageId != clientMessageId,
          ),
          message,
        ];
      }
      return true;
    } catch (cause) {
      sendObservation.failed(clientMessageId, cause);
      if (!active()) return false;
      if (!uncertainDelivery(cause)) blockedSendRetries.add(clientMessageId);
      if (pendingDirectSends.containsKey(clientMessageId)) {
        pendingDirectSends[clientMessageId] = pending.withSendStatus(
          MessageSendStatus.failed,
        );
        if (selectedDirectMessage?.id == conversation.id) {
          directMessageHistory = withPendingDirect(
            conversation.id,
            directMessageHistory,
          );
        }
      }
      if (isReady() && selectedDirectMessage?.id == conversation.id) {
        error = formatError(cause);
      }
      return false;
    } finally {
      if (active()) {
        sending = false;
        changed();
      }
    }
  }
}
