part of '../../app_state_test.dart';

void _registerHistoryEdit() {
  test('edits a text message using its current revision', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    final edited = await state.editText(state.messages.single, 'Исправлено');

    expect(edited, isTrue);
    expect(state.messages.single.body, 'Исправлено');
    expect(api.editedRevision, 1);
  });

  test(
    'refreshes a conflicted older text revision without losing history',
    () async {
      final api = _FakeApi(topology, paginated: true)..failTextEdits = 1;
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();
      await state.loadOlderMessages();
      final original = state.messages.first;

      final result = await state.editTextWithResult(
        original,
        'Мой черновик',
        original.revision,
      );
      expect(result.kind, MessageEditStatus.conflict);
      expect(state.messages.map((message) => message.id), [
        'message-older',
        'message-1',
      ]);

      api.olderTextRevision = 2;
      final refreshed = await state.refreshTextMessageRevision(original);
      expect(refreshed?.revision, 2);
      expect(state.messages.map((message) => message.id), [
        'message-older',
        'message-1',
      ]);
      expect(
        (await state.editTextWithResult(original, 'Мой черновик', 2)).kind,
        MessageEditStatus.saved,
      );
      expect(api.editedRevision, 2);
      expect(state.messages.first.body, 'Мой черновик');
    },
  );

  test(
    'refreshes a conflicted older DM revision without losing history',
    () async {
      final api = _FakeApi(
        topology,
        includeDirectMessage: true,
        paginated: true,
      )..failDirectEdits = 1;
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();
      await state.openDirectConversation(state.directMessages.single);
      await state.loadOlderDirectMessages();
      final original = state.directMessageHistory.first;

      final result = await state.editDirectWithResult(
        original,
        'Мой черновик',
        original.revision,
      );
      expect(result.kind, MessageEditStatus.conflict);
      api.olderDirectRevision = 2;
      final refreshed = await state.refreshDirectMessageRevision(original);
      expect(refreshed?.revision, 2);
      expect(state.directMessageHistory.map((message) => message.id), [
        'dm-message-older',
        'dm-message-1',
      ]);
      expect(
        (await state.editDirectWithResult(original, 'Мой черновик', 2)).kind,
        MessageEditStatus.saved,
      );
      expect(api.editedDirectRevision, 2);
    },
  );
}
