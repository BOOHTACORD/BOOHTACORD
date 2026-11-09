part of '../../app_state_test.dart';

void _registerDirectSend() {
  test('reuses the direct send ID without inserting into another DM', () async {
    final api = _FakeApi(topology, includeDirectMessage: true)
      ..failDirectSends = 1;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    final first = state.directMessages.single;
    await state.openDirectConversation(first);

    expect(await state.sendDirect('Личное приветствие'), isFalse);
    final failedId = state.directMessageHistory.last.clientMessageId!;
    expect(
      state.directMessageHistory.last.sendStatus,
      MessageSendStatus.failed,
    );
    const other = DirectConversation(
      id: 'dm-2',
      participantId: 'account-3',
      displayName: 'Другой собеседник',
      unreadCount: 0,
    );
    await state.openDirectConversation(other);
    expect(await state.sendDirect('Другое сообщение'), isTrue);
    expect(state.directMessageHistory.last.body, 'Другое сообщение');
    await state.openDirectConversation(first);
    expect(
      state.directMessageHistory.last.sendStatus,
      MessageSendStatus.failed,
    );
    expect(await state.retryDirectSend(failedId), isTrue);
    expect(api.directSendIds.last, api.directSendIds.first);
    expect(api.directSendIds[1], isNot(api.directSendIds.first));
  });

  test('allows attachment-only DM messages but rejects an empty draft without files', () async {
    final api = _FakeApi(topology, includeDirectMessage: true);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);

    expect(await state.sendDirect(''), isFalse);
    expect(api.directSendIds, isEmpty);
    expect(
      await state.sendDirect(
        '',
        attachments: const [
          MessageAttachment(
            id: 'dm-file-image',
            originalName: 'clipboard.png',
            sizeBytes: 4,
          ),
        ],
      ),
      isTrue,
    );
    expect(api.sentDirectAttachmentIds, ['dm-file-image']);
    expect(state.directMessageHistory.last.body, isEmpty);
    expect(
      state.directMessageHistory.last.attachments.single.id,
      'dm-file-image',
    );
  });
}
