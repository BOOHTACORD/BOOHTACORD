import '../../../models.dart';
import '../../profile/revision/cache.dart';
import '../../profile/revision/member_refresh.dart';
import '../lifecycle/controller.dart';
import 'direct_names.dart';
export 'members_refresh.dart';

extension WorkspaceMembers on WorkspaceController {
  MemberPresence memberPresence(GuildMember member) =>
      guildPresence.resolve(member.id, member.presence);

  Future<void> refreshMemberProfile(String userId, int minimumRevision) =>
      _refreshMemberProfile(userId, minimumRevision, 0);

  Future<void> _refreshMemberProfile(
    String userId,
    int minimumRevision,
    int retry,
  ) async {
    final ticket = scope.capture();
    final cached = members.where((member) => member.id == userId).firstOrNull;
    final cachedRevision = cached == null
        ? null
        : memberProfileRevisions.memberRevision(cached);
    if (!accepts(ticket) ||
        (cachedRevision != null && cachedRevision >= minimumRevision)) {
      return;
    }
    try {
      final result = await memberProfileRefreshes.refresh(
        scope,
        userId,
        minimumRevision,
        () => api.memberProfile(userId),
        memberProfileRevisions.memberRevision,
      );
      if (!accepts(ticket)) return;
      if (result.id != userId) return;
      if ((memberProfileRevisions.memberRevision(result) ?? 0) <
          minimumRevision) {
        final latest = members
            .where((member) => member.id == userId)
            .firstOrNull;
        final latestRevision = latest == null
            ? null
            : memberProfileRevisions.memberRevision(latest);
        if (retry == 0 &&
            (latestRevision == null || latestRevision < minimumRevision)) {
          await _refreshMemberProfile(userId, minimumRevision, 1);
        }
        return;
      }
      updateDirectNamesForMember(this, userId, result.displayName);
      final index = members.indexWhere((member) => member.id == userId);
      if (index < 0) {
        members = [...members, result];
        changed();
        return;
      }
      final current = members[index];
      if ((memberProfileRevisions.memberRevision(current) ?? 0) >=
          (memberProfileRevisions.memberRevision(result) ?? 0)) {
        return;
      }
      final updated = [...members];
      updated[index] = memberProfileRevisions.withLatestProfile(
        result,
        current,
      );
      members = updated;
      changed();
    } catch (cause) {
      if (accepts(ticket)) effects.error(effects.message(cause));
    }
  }
}
