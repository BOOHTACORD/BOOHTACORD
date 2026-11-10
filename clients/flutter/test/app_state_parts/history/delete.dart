part of '../../app_state_test.dart';

void _registerHistoryDelete() {
  test('deletes an older text row without discarding loaded pages', () async {
    final api = _FakeApi(topology, paginated: true);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    await state.loadOlderMessages();

    await state.deleteText(state.messages.first);

    expect(api.deletedTextMessageId, 'message-older');
    expect(state.messages.map((message) => message.id), [
      'message-older',
      'message-1',
    ]);
    expect(state.messages.first.deleted, isTrue);
    expect(state.messages.first.body, isEmpty);
    expect(state.messages.first.revision, 2);
    expect(api.olderPageRequests, 1);
  });

  test('deletes an older DM row without discarding loaded pages', () async {
    final api = _FakeApi(topology, includeDirectMessage: true, paginated: true);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await state.loadOlderDirectMessages();

    await state.deleteDirect(state.directMessageHistory.first);

    expect(api.deletedDirectMessageId, 'dm-message-older');
    expect(state.directMessageHistory.map((message) => message.id), [
      'dm-message-older',
      'dm-message-1',
    ]);
    expect(state.directMessageHistory.first.deleted, isTrue);
    expect(state.directMessageHistory.first.revision, 2);
  });

  test('does not place a delayed edit into the next channel', () async {
    final gate = Completer<void>();
    final api = _FakeApi(topology)..textEditGate = gate;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    final pending = state.editTextWithResult(
      state.messages.single,
      'Запоздавший текст',
      1,
    );
    const other = GuildChannel(
      id: 'channel-2',
      name: 'другой',
      kind: ChannelKind.text,
      admissionClosed: false,
    );
    await state.selectChannel(other);
    gate.complete();

    expect((await pending).kind, MessageEditStatus.stale);
    expect(
      state.messages.every((message) => message.channelId == other.id),
      isTrue,
    );
  });
}
