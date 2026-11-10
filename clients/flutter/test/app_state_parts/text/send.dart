part of '../../app_state_test.dart';

void _registerTextSend() {
  test('adds a server-confirmed message to the conversation', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    final sent = await state.send(
      'Новое сообщение',
      replyToId: 'message-reply-target',
      mentionUserIds: ['account-2', 'account-2'],
      attachments: const [
        MessageAttachment(id: 'file-1', originalName: 'file.txt', sizeBytes: 3),
      ],
    );

    expect(sent, isTrue);
    expect(state.messages.last.body, 'Новое сообщение');
    expect(state.messages.last.replyToId, 'message-reply-target');
    expect(api.sentReplyToId, 'message-reply-target');
    expect(api.sentMentionIds, ['account-2']);
    expect(api.sentAttachmentIds, ['file-1']);
    expect(state.messages.last.attachments.single.id, 'file-1');
    expect(state.sending, isFalse);
  });

  test('reuses the text send ID after an uncertain failure', () async {
    final api = _FakeApi(topology)..failTextSends = 1;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.send('Привет', replyToId: 'message-1'), isFalse);
    final failed = state.messages.last;
    expect(failed.sendStatus, MessageSendStatus.failed);
    expect(failed.clientMessageId, api.textSendIds.single);
    expect(await state.retryTextSend(failed.clientMessageId!), isTrue);
    expect(api.textSendIds[1], api.textSendIds[0]);
    expect(
      state.messages.where((message) => message.body == 'Привет'),
      hasLength(1),
    );

    expect(await state.send('Другой текст'), isTrue);
    expect(api.textSendIds[2], isNot(api.textSendIds[1]));
  });

  test('counts Unicode code points for the message limit', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.send('🙂' * 5000), isTrue);
    expect(state.messages.last.body.runes.length, 5000);
  });

  test('allows attachment-only TEXT messages but rejects a blank draft without files', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.send(''), isFalse);
    expect(api.textSendIds, isEmpty);
    expect(
      await state.send(
        '',
        attachments: const [
          MessageAttachment(
            id: 'file-image',
            originalName: 'clipboard.png',
            sizeBytes: 4,
          ),
        ],
      ),
      isTrue,
    );
    expect(api.sentAttachmentIds, ['file-image']);
    expect(state.messages.last.body, isEmpty);
    expect(state.messages.last.attachments.single.id, 'file-image');
  });

  test('reconciles a lost text acknowledgement with server history', () async {
    final api = _FakeApi(topology)..failTextSends = 1;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.send('Привет'), isFalse);
    expect(state.messages.last.sendStatus, MessageSendStatus.failed);
    api.committedTextClientId = api.textSendIds.single;
    await state.selectChannel(textChannel);
    expect(
      state.messages.where((message) => message.body == 'Привет'),
      hasLength(1),
    );
    expect(state.messages.last.sendStatus, isNull);
    expect(await state.retryTextSend(api.textSendIds.first), isFalse);

    expect(await state.send('Привет'), isTrue);
    expect(api.textSendIds.last, isNot(api.textSendIds.first));
  });
}
