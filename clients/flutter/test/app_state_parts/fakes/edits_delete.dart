part of '../../app_state_test.dart';

mixin _FakeEditsDelete on _FakeApiState {
  @override
  Future<DirectChatMessage> editDirectMessage(
    String directMessageId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) async {
    editedDirectRevision = expectedRevision;
    if (failDirectEdits > 0) {
      failDirectEdits--;
      throw const ApiFailure('Конфликт редакции', status: 409);
    }
    return DirectChatMessage(
      id: messageId,
      directMessageId: directMessageId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 19),
      deleted: false,
      revision: expectedRevision + 1,
    );
  }

  @override
  Future<void> deleteMessage(String channelId, String messageId) async {
    deletedTextMessageId = messageId;
  }

  @override
  Future<void> deleteDirectMessage(
    String directMessageId,
    String messageId,
  ) async {
    deletedDirectMessageId = messageId;
  }
}
