import '../../../core/session/scope.dart';
import '../../../models.dart';
import '../../../services/api_client.dart';
import '../../profile/revision/cache.dart';
import '../../profile/revision/member_refresh.dart';

final _generations = Expando<_Generation>('welcome-author-generation');

Future<GuildMember> loadWelcomeAuthor(
  SessionScope scope,
  ApiClient api,
  String id,
) {
  var generation = _generations[scope];
  if (generation == null || !generation.ticket.isCurrent) {
    generation = _Generation(scope.capture());
    _generations[scope] = generation;
  }
  return memberProfileRefreshes.refresh(
    generation,
    id,
    0,
    () => api.memberProfile(id),
    memberProfileRevisions.memberRevision,
  );
}

class _Generation {
  _Generation(this.ticket);
  final SessionTicket ticket;
}
