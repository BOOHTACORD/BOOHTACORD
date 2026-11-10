part of '../../app_state_test.dart';

mixin _FakeTopology on _FakeApiState {
  @override
  Future<ChannelTopology> topology() async => value;

  @override
  Future<void> advanceTextChannelReadCursor(
    String channelId,
    String messageId,
  ) async {
    advancedTextChannelId = channelId;
    advancedTextMessageId = messageId;
    textReadAdvances++;
    final gate = textReadCursorGates[messageId];
    if (gate != null) await gate.future;
  }

  @override
  Future<List<GuildMember>> members() async => const [];

  @override
  Future<List<DirectConversation>> directMessages() async =>
      includeDirectMessage
      ? const [
          DirectConversation(
            id: 'dm-1',
            participantId: 'account-2',
            displayName: 'Собеседник',
            unreadCount: 1,
          ),
        ]
      : const [];
}
