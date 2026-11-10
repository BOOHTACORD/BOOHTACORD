part of '../../app_state_test.dart';

void _registerTextReadCursor() {
  test(
    'advances text read cursor once for the newest visible message',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();

      await state.markTextChannelRead(textChannel.id, state.messages.last.id);
      await state.markTextChannelRead(textChannel.id, state.messages.last.id);

      expect(api.advancedTextChannelId, textChannel.id);
      expect(api.advancedTextMessageId, 'message-1');
      expect(api.textReadAdvances, 1);
    },
  );

  test(
    'advances text read cursor across equal timestamps in server order',
    () async {
      final api = _FakeApi(topology)..reverseEqualTimestampMessageIds = true;
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();

      expect(state.messages.map((message) => message.id), [
        'message-a',
        'message-z',
      ]);
      await state.markTextChannelRead(textChannel.id, 'message-a');
      await state.markTextChannelRead(textChannel.id, 'message-z');

      expect(api.textReadAdvances, 2);
      expect(api.advancedTextMessageId, 'message-z');
    },
  );

  test('keeps text read cursor monotonic when equal-time requests finish out of order', () async {
    final api = _FakeApi(topology)..reverseEqualTimestampMessageIds = true;
    final olderRequest = Completer<void>();
    final newerRequest = Completer<void>();
    api.textReadCursorGates['message-a'] = olderRequest;
    api.textReadCursorGates['message-z'] = newerRequest;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    final markOlder = state.markTextChannelRead(textChannel.id, 'message-a');
    final markNewer = state.markTextChannelRead(textChannel.id, 'message-z');
    expect(api.textReadAdvances, 2);

    newerRequest.complete();
    await markNewer;
    olderRequest.complete();
    await markOlder;
    await state.markTextChannelRead(textChannel.id, 'message-z');

    expect(api.textReadAdvances, 2);
  });
}
