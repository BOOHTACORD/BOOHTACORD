import '../../profile/revision/cache.dart';
import '../lifecycle/controller.dart';
import 'direct_names.dart';

final _owners = Expando<_MemberLoadOwner>();
_MemberLoadOwner _owner(WorkspaceController workspace) =>
    _owners[workspace] ??= _MemberLoadOwner();

class _MemberLoadOwner {
  int sequence = 0;
  int? realtime;
  int begin(bool strict) {
    final next = ++sequence;
    realtime = strict ? next : null;
    return next;
  }
  void finish(int current) {
    if (realtime == current) realtime = null;
  }
  bool socketEnd() {
    if (realtime != sequence) return false;
    sequence++;
    realtime = null;
    return true;
  }
}

extension WorkspaceMemberRefresh on WorkspaceController {
  Future<void> refreshMembers({bool strict = false}) async {
    final ticket = scope.capture();
    if (!accepts(ticket)) return;
    final owner = _owner(this), sequence = owner.begin(strict);
    bool current() => accepts(ticket) && owner.sequence == sequence;
    final previousIds = members.map((member) => member.id).toSet();
    membersLoading = true;
    membersError = null;
    changed();
    try {
      final result = await api.members();
      if (current()) {
        final existing = {for (final member in members) member.id: member};
        final returnedIds = result.map((member) => member.id).toSet();
        final incoming = result.map((member) {
          final previous = existing[member.id];
          return previous == null ? member : memberProfileRevisions.preserveNewer(member, previous);
        }).toList(growable: true);
        incoming.addAll(members.where((member) =>
            !previousIds.contains(member.id) && !returnedIds.contains(member.id)));
        members = incoming;
        for (final member in members) {
          updateDirectNamesForMember(this, member.id, member.displayName);
        }
      }
    } catch (cause) {
      if (strict && current()) rethrow;
      if (current()) membersError = effects.message(cause);
    } finally {
      if (current()) {
        membersLoading = false;
        changed();
      }
      owner.finish(sequence);
    }
  }

  void invalidateRealtimeMembers() {
    if (_owner(this).socketEnd()) {
      membersLoading = false;
      changed();
    }
  }
}
