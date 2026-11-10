part of '../../app_state_test.dart';

mixin _FakeSearch on _FakeApiState {
  @override
  Future<ChatMessage?> findSentText(
    String conversation,
    String client,
    String owner,
  ) async => null;

  @override
  Future<DirectChatMessage?> findSentDirect(
    String conversation,
    String client,
    String owner,
  ) async => null;
}
