import 'dart:async';

import 'package:boohtacord_desktop/src/features/profile/revision/cache.dart';
import 'package:boohtacord_desktop/src/features/workspace/load_members/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'member_profile_fakes.dart';

class PendingMembersApi extends DelayedMemberProfileApi {
  final page = Completer<List<GuildMember>>();
  @override
  Future<List<GuildMember>> members() => page.future;
}

void main() {
  test(
    'keeps an arriving member when an older directory load completes',
    () async {
      final api = PendingMembersApi();
      final workspace = workspaceFor(api);
      addTearDown(workspace.dispose);
      final loading = workspace.refreshMembers();
      final arrival = workspace.refreshMemberProfile('u1', 0);
      api.reads.single.complete(revisionMember('New member', 1));
      await arrival;
      api.page.complete([]);
      await loading;
      expect(workspace.members.map((member) => member.id), ['u1']);
    },
  );
  test(
    'adds a newly online member and coalesces simultaneous lookups',
    () async {
      final api = DelayedMemberProfileApi();
      final workspace = workspaceFor(api);
      addTearDown(workspace.dispose);
      final first = workspace.refreshMemberProfile('u1', 0);
      final second = workspace.refreshMemberProfile('u1', 0);
      expect(api.reads, hasLength(1));
      api.reads.single.complete(revisionMember('New member', 1));
      await Future.wait([first, second]);
      expect(workspace.members.map((member) => member.displayName), [
        'New member',
      ]);
    },
  );

  test(
    'coalesces profile hints and follows the newest server revision',
    () async {
      final api = DelayedMemberProfileApi();
      final workspace = workspaceFor(api);
      addTearDown(workspace.dispose);
      final initial = revisionMember(
        'Initial',
        1,
        presence: MemberPresence.online,
      );
      workspace.members = [initial];

      final first = workspace.refreshMemberProfile('u1', 2);
      final second = workspace.refreshMemberProfile('u1', 3);
      expect(api.reads, hasLength(1));
      api.reads.single.complete(revisionMember('Revision 2', 2));
      await Future<void>.delayed(Duration.zero);
      expect(api.reads, hasLength(2));
      api.reads.last.complete(revisionMember('Revision 3', 3));
      await Future.wait([first, second]);

      expect(workspace.members.single.displayName, 'Revision 3');
      expect(
        memberProfileRevisions.memberRevision(workspace.members.single),
        3,
      );
      expect(workspace.members.single.presence, MemberPresence.online);
    },
  );
}
