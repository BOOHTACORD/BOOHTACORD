part of '../../app_state_test.dart';

void _registerHistoryReconcile() {
  test('orders equal-timestamp DM messages by id like web', () async {
    final api = _FakeApi(topology, includeDirectMessage: true)
      ..reverseEqualTimestampMessageIds = true;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    await state.showDirectMessages();
    await state.openDirectConversation(state.directMessages.single);

    expect(state.directMessageHistory.map((message) => message.id), [
      'dm-message-a',
      'dm-message-z',
    ]);
  });

  test(
    'older text pages prefer the newer revision of an overlapping row',
    () async {
      final api = _FakeApi(topology, paginated: true)
        ..overlappingTextRevision = 2;
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();

      expect(await state.loadOlderMessages(), isTrue);

      final overlap = state.messages.singleWhere(
        (message) => message.id == 'message-1',
      );
      expect(overlap.revision, 2);
      expect(overlap.body, 'Обновлённая версия');
    },
  );

  test(
    'older DM pages prefer the newer revision of an overlapping row',
    () async {
      final api = _FakeApi(
        topology,
        includeDirectMessage: true,
        paginated: true,
      )..overlappingDirectRevision = 2;
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();
      await state.openDirectConversation(state.directMessages.single);

      expect(await state.loadOlderDirectMessages(), isTrue);

      final overlap = state.directMessageHistory.singleWhere(
        (message) => message.id == 'dm-message-1',
      );
      expect(overlap.revision, 2);
      expect(overlap.body, 'Обновлённое личное сообщение');
    },
  );

  test(
    'realtime text refresh preserves already loaded history pages',
    () async {
      final api = _FakeApi(topology, paginated: true);
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();
      await state.loadOlderMessages();
      api.committedTextClientId = 'realtime-client-message';

      await state.refreshSelectedTextHistory();

      expect(state.messages.map((message) => message.id), [
        'message-older',
        'message-1',
        'message-committed',
      ]);
      expect(state.nextMessageCursor, isNull);
    },
  );

  test(
    'text refresh cannot leave message loading stuck after channel switch',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();
      final pageGate = Completer<ChatMessagePage>();
      api.messagePageGate = pageGate;

      final refresh = state.refreshSelectedTextHistory();
      await Future<void>.delayed(Duration.zero);
      await state.selectChannel(
        const GuildChannel(
          id: 'voice-1',
          name: 'Голосовой',
          kind: ChannelKind.voice,
          admissionClosed: false,
        ),
      );
      pageGate.complete(const ChatMessagePage(messages: []));
      await refresh;

      expect(state.selectedChannel?.id, 'voice-1');
      expect(state.loadingMessages, isFalse);
    },
  );
}
