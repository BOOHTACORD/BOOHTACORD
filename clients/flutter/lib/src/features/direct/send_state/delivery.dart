import '../../conversation/lifecycle/controller.dart';
import '../../conversation/delivery/recovery.dart';
import 'hydrate.dart';

extension DirectDelivery on ConversationController {
  Future<DirectChatMessage> deliverDirect(
    DirectChatMessage draft,
    bool retry,
    bool Function() active,
  ) async {
    final message =
        directSendReceipts[draft.clientMessageId] ??
        await recoverDelivery<DirectChatMessage>(
          post: () => api.sendDirectMessage(
            draft.directMessageId,
            draft.clientMessageId!,
            draft.body,
            replyToId: draft.replyToId,
            mentionUserIds: draft.mentionUserIds,
            attachmentIds: draft.attachments.map((row) => row.id).toList(),
          ),
          lookup: () => api.findSentDirect(
            draft.directMessageId,
            draft.clientMessageId!,
            draft.authorId,
          ),
          status: (status) {
            if (!active() ||
                !pendingDirectSends.containsKey(draft.clientMessageId)) {
              return;
            }
            pendingDirectSends[draft.clientMessageId!] = draft.withSendStatus(
              status == 'checking'
                  ? MessageSendStatus.checking
                  : MessageSendStatus.sending,
            );
            if (selectedDirectMessage?.id == draft.directMessageId) {
              directMessageHistory = withPendingDirect(
                draft.directMessageId,
                directMessageHistory,
              );
            }
            changed();
          },
          active: active,
          retry: retry,
        );
    if (draft.attachments.isEmpty) return message;
    if (!active()) throw StateError('Сеанс изменился. Отправка остановлена.');
    validateDirectReceipt(message, draft);
    directSendReceipts[draft.clientMessageId!] = message;
    return hydrateDirect(draft, message, active);
  }
}
