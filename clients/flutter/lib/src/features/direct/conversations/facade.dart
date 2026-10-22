import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';
import 'candidate_page.dart';

mixin DirectConversationsFacade on ApiFacadeBase {
  late final _directConversations = DirectConversationsApi(transport);
  Future<void> acceptSupportPublication(int version) => transport.run(
    () => _directConversations.acceptSupportPublication(version),
  );

  Future<List<DirectConversation>> directMessages() =>
      transport.run(() => _directConversations.directMessages());

  Future<List<DirectCandidate>> directMessageCandidates() =>
      transport.run(() => _directConversations.directMessageCandidates());

  Future<DirectCandidatePage> directMessageCandidatePage({String? after}) =>
      transport.run(() => _directConversations.candidatePage(after: after));

  Future<String> openDirectMessage(String participantId) => transport.run(
    () => _directConversations.openDirectMessage(participantId),
  );
}
