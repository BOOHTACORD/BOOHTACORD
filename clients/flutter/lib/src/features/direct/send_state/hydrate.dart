import '../../conversation/lifecycle/controller.dart';
import '../../conversation/delivery/recovery.dart';

void validateDirectReceipt(
  DirectChatMessage row,
  DirectChatMessage draft, {
  String? messageId,
}) {
  if (row.id.isEmpty ||
      row.id.startsWith('optimistic:') ||
      messageId != null && row.id != messageId ||
      row.directMessageId != draft.directMessageId ||
      row.authorId != draft.authorId ||
      row.clientMessageId != draft.clientMessageId) {
    throw const ApiFailure(
      'Подтверждение сообщения не совпало. Повторная отправка остановлена.',
      status: 409,
      code: 'DIRECT_DELIVERY_MISMATCH',
    );
  }
}

bool _complete(DirectChatMessage row, DirectChatMessage draft) =>
    row.deleted ||
    row.attachments.length == draft.attachments.length &&
        draft.attachments.every(
          (file) => row.attachments.any((value) => value.id == file.id),
        );

extension DirectSendHydration on ConversationController {
  DirectChatMessage newestDirectMessage(
    DirectChatMessage draft,
    DirectChatMessage candidate,
  ) {
    validateDirectReceipt(candidate, draft);
    var newest = candidate;
    for (final row in directMessageHistory) {
      if (row.id != candidate.id ||
          row.clientMessageId != draft.clientMessageId ||
          row.authorId != draft.authorId ||
          row.directMessageId != draft.directMessageId ||
          row.sendStatus != null) {
        continue;
      }
      if (row.deleted && !newest.deleted ||
          row.deleted == newest.deleted &&
              (row.revision > newest.revision ||
                  row.revision == newest.revision &&
                      _complete(row, draft) &&
                      !_complete(newest, draft))) {
        newest = row;
      }
    }
    return newest;
  }

  Future<DirectChatMessage> hydrateDirect(
    DirectChatMessage draft,
    DirectChatMessage receipt,
    bool Function() active,
  ) async {
    void ensure() {
      if (!active()) throw StateError('Сеанс изменился. Проверка остановлена.');
    }

    ensure();
    final cached = newestDirectMessage(draft, receipt);
    if (_complete(cached, draft)) return cached;
    final client = draft.clientMessageId!;
    if (pendingDirectSends.containsKey(client)) {
      pendingDirectSends[client] = draft.withSendStatus(
        MessageSendStatus.checking,
      );
      if (selectedDirectMessage?.id == draft.directMessageId) {
        directMessageHistory = withPendingDirect(
          draft.directMessageId,
          directMessageHistory,
        );
      }
      changed();
    }
    DirectChatMessage? canonical;
    try {
      canonical = await api
          .findSentDirect(draft.directMessageId, client, draft.authorId)
          .timeout(const Duration(seconds: 20));
    } catch (cause) {
      ensure();
      final latest = newestDirectMessage(draft, receipt);
      if (uncertainDelivery(cause) && _complete(latest, draft)) return latest;
      rethrow;
    }
    ensure();
    if (canonical == null) {
      throw const ApiFailure(
        'Сообщение сохранено. Повторите проверку доставки.',
      );
    }
    validateDirectReceipt(canonical, draft, messageId: receipt.id);
    final latest = newestDirectMessage(draft, canonical);
    if (!_complete(latest, draft)) {
      throw const ApiFailure('Сообщение сохранено. Вложения пока недоступны.');
    }
    return latest;
  }
}
