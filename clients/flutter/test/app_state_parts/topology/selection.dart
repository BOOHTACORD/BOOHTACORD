part of '../../app_state_test.dart';

void _registerTopologySelection() {
  test(
    'clears the selected channel when refreshed topology archives it',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();
      expect(state.selectedChannel?.id, textChannel.id);

      api.value = const ChannelTopology(revision: 2, categories: []);
      await state.refreshTopology();

      expect(state.topology?.revision, 2);
      expect(state.selectedChannel, isNull);
      expect(state.messages, isEmpty);
      expect(state.nextMessageCursor, isNull);
    },
  );
}
