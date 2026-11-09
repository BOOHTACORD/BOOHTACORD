part of '../../app_state_test.dart';

void _registerDirectRead() {
  test('loads a direct message and advances cursor after rendering', () async {
    final api = _FakeApi(topology, includeDirectMessage: true);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    await state.showDirectMessages();
    await state.openDirectConversation(state.directMessages.single);
    await state.markSelectedDirectMessageRead();

    expect(state.directMessageHistory.single.body, 'Личное сообщение');
    expect(state.directMessages.single.unreadCount, 0);
    expect(api.advancedMessageId, 'dm-message-1');
    expect(
      await state.sendDirect(
        'Ответ',
        replyToId: 'dm-message-1',
        mentionUserIds: ['account-2'],
        attachments: const [
          MessageAttachment(id: 'file-2', originalName: 'dm.txt', sizeBytes: 4),
        ],
      ),
      isTrue,
    );
    expect(api.sentDirectReplyToId, 'dm-message-1');
    expect(api.sentDirectMentionIds, ['account-2']);
    expect(api.sentDirectAttachmentIds, ['file-2']);
    expect(state.directMessageHistory.last.attachments.single.id, 'file-2');
    expect(state.directMessageHistory.last.replyToId, 'dm-message-1');
  });
}
