part of '../../app_state_test.dart';

mixin _FakeTextHistory on _FakeApiState {
  @override
  Future<List<ChatMessage>> messages(String channelId) async =>
      reverseEqualTimestampMessageIds
      ? [
          for (final messageId in ['message-z', 'message-a'])
            ChatMessage(
              id: messageId,
              channelId: channelId,
              authorId: 'account-1',
              body: messageId,
              createdAt: DateTime.utc(2026, 9, 20),
              deleted: false,
              revision: 1,
            ),
        ]
      : [
          ChatMessage(
            id: 'message-1',
            channelId: channelId,
            authorId: 'account-1',
            body: 'Первое сообщение',
            createdAt: DateTime.utc(2026, 9, 20),
            deleted: false,
            revision: 1,
          ),
        ];

  @override
  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) async {
    if (before == null && at == null && messagePageGate != null) {
      return messagePageGate!.future;
    }
    if (paginated && before != null) {
      olderPageRequests++;
      return ChatMessagePage(
        messages: [
          ChatMessage(
            id: 'message-older',
            channelId: channelId,
            authorId: 'account-2',
            body: 'Старое сообщение',
            createdAt: DateTime.utc(2026, 9, 19),
            deleted: false,
            revision: olderTextRevision,
          ),
          if (overlappingTextRevision case final revision?)
            ChatMessage(
              id: 'message-1',
              channelId: channelId,
              authorId: 'account-1',
              body: 'Обновлённая версия',
              createdAt: DateTime.utc(2026, 9, 20),
              deleted: false,
              revision: revision,
            ),
        ],
      );
    }
    return ChatMessagePage(
      messages: [
        ...await messages(channelId),
        if (committedTextClientId != null)
          ChatMessage(
            id: 'message-committed',
            channelId: channelId,
            authorId: 'account-1',
            clientMessageId: committedTextClientId,
            body: 'Привет',
            createdAt: DateTime.utc(2026, 9, 20, 1),
            deleted: false,
            revision: 1,
          ),
      ],
      nextCursor: paginated ? 'older-page' : null,
    );
  }
}
