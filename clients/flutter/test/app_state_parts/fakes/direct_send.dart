part of '../../app_state_test.dart';

mixin _FakeDirectSend on _FakeApiState {
  @override
  Future<DirectChatMessage> sendDirectMessage(
    String directMessageId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    directSendIds.add(clientMessageId);
    if (failDirectSends > 0) {
      failDirectSends--;
      throw const ApiFailure('Подтверждение отправки потеряно.');
    }
    sentDirectReplyToId = replyToId;
    sentDirectMentionIds = mentionUserIds;
    sentDirectAttachmentIds = attachmentIds;
    return DirectChatMessage(
      id: 'dm-message-${directSendIds.length + 1}',
      directMessageId: directMessageId,
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
  Future<List<DirectCandidate>> directMessageCandidates() async => const [];

  @override
  Future<List<DirectChatMessage>> directMessageHistory(String id) async =>
      reverseEqualTimestampMessageIds
      ? [
          for (final messageId in ['dm-message-z', 'dm-message-a'])
            DirectChatMessage(
              id: messageId,
              directMessageId: id,
              authorId: 'account-2',
              body: messageId,
              createdAt: DateTime.utc(2026, 9, 24),
              deleted: false,
              revision: 1,
            ),
        ]
      : [
          DirectChatMessage(
            id: 'dm-message-1',
            directMessageId: id,
            authorId: 'account-2',
            body: 'Личное сообщение',
            createdAt: DateTime.utc(2026, 9, 24),
            deleted: false,
            revision: 1,
          ),
        ];
}
