part of '../app_state_test.dart';

void _registerAttachmentRouting() {
  test('routes attachment bytes to the explicit conversation', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    final bytes = Uint8List.fromList([1, 2]);
    const other = GuildChannel(
      id: 'channel-2',
      name: 'другой',
      kind: ChannelKind.text,
      admissionClosed: false,
    );
    await state.selectChannel(other);

    await state.uploadAttachment('text.txt', bytes, channelId: textChannel.id);
    await state.uploadAttachment('dm.txt', bytes, directMessageId: 'dm-1');

    expect(api.uploadedTextChannelId, textChannel.id);
    expect(api.uploadedDirectMessageId, 'dm-1');
  });
}
