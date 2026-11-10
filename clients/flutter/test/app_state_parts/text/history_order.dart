part of '../../app_state_test.dart';

void _registerTextHistoryOrder() {
  test('does not append a delayed text send into the next channel', () async {
    final gate = Completer<void>();
    final api = _FakeApi(topology)..textSendGate = gate;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    final pending = state.send('Сообщение первого канала');
    expect(state.messages.last.sendStatus, MessageSendStatus.sending);
    const other = GuildChannel(
      id: 'channel-2',
      name: 'другой',
      kind: ChannelKind.text,
      admissionClosed: false,
    );
    await state.selectChannel(other);
    gate.complete();
    expect(await pending, isTrue);
    expect(state.selectedChannel?.id, other.id);
    expect(
      state.messages.every((message) => message.channelId == other.id),
      isTrue,
    );
  });

  test(
    'loads older text history by cursor without duplicating messages',
    () async {
      final api = _FakeApi(topology, paginated: true);
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();

      expect(state.nextMessageCursor, 'older-page');
      expect(await state.loadOlderMessages(), isTrue);
      expect(state.messages.map((message) => message.id), [
        'message-older',
        'message-1',
      ]);
      expect(state.nextMessageCursor, isNull);
      expect(api.olderPageRequests, 1);
    },
  );

  test('orders equal-timestamp text messages by id like web', () async {
    final api = _FakeApi(topology)..reverseEqualTimestampMessageIds = true;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    expect(state.messages.map((message) => message.id), [
      'message-a',
      'message-z',
    ]);
  });
}
