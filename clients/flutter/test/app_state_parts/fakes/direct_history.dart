part of '../../app_state_test.dart';

mixin _FakeDirectHistory on _FakeApiState {
  @override
  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,
    String? at,
  }) async => paginated
      ? before != null
            ? DirectChatMessagePage(
                messages: [
                  DirectChatMessage(
                    id: 'dm-message-older',
                    directMessageId: id,
                    authorId: 'account-1',
                    body: 'Старое личное сообщение',
                    createdAt: DateTime.utc(2026, 9, 19),
                    deleted: false,
                    revision: olderDirectRevision,
                  ),
                  if (overlappingDirectRevision case final revision?)
                    DirectChatMessage(
                      id: 'dm-message-1',
                      directMessageId: id,
                      authorId: 'account-2',
                      body: 'Обновлённое личное сообщение',
                      createdAt: DateTime.utc(2026, 9, 24),
                      deleted: false,
                      revision: revision,
                    ),
                ],
              )
            : DirectChatMessagePage(
                messages: await directMessageHistory(id),
                nextCursor: 'older-dm-page',
              )
      : DirectChatMessagePage(messages: await directMessageHistory(id));

  @override
  Future<void> advanceDirectMessageReadCursor(
    String directMessageId,
    String messageId,
  ) async {
    advancedMessageId = messageId;
  }
}
