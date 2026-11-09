part of '../../app_state_test.dart';

mixin _FakeTextWrite on _FakeApiState {
  @override
  Future<ChatMessage> sendMessage(
    String channelId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    await textSendGate?.future;
    textSendIds.add(clientMessageId);
    if (failTextSends > 0) {
      failTextSends--;
      throw const ApiFailure('Подтверждение отправки потеряно.');
    }
    sentReplyToId = replyToId;
    sentMentionIds = mentionUserIds;
    sentAttachmentIds = attachmentIds;
    return ChatMessage(
      id: 'message-${textSendIds.length + 1}',
      channelId: channelId,
      clientMessageId: clientMessageId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 20, 1),
      deleted: false,
      revision: 1,
      replyToId: replyToId,
      attachments: [
        for (final id in attachmentIds)
          MessageAttachment(id: id, originalName: 'file.txt', sizeBytes: 3),
      ],
    );
  }

  @override
  Future<ChatMessage> editMessage(
    String channelId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) async {
    await textEditGate?.future;
    editedRevision = expectedRevision;
    if (failTextEdits > 0) {
      failTextEdits--;
      throw const ApiFailure('Конфликт редакции', status: 409);
    }
    return ChatMessage(
      id: messageId,
      channelId: channelId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 20),
      deleted: false,
      revision: expectedRevision + 1,
    );
  }
}
