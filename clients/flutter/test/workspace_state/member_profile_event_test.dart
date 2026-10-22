import 'dart:async';

import 'package:boohtacord_desktop/src/features/realtime/dispatch/member_profile.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'member_profile_fakes.dart';

void main() {
  test(
    'dispatches a valid hint and ignores unexpected payload fields',
    () async {
      final api = ImmediateMemberProfileApi(revisionMember('Fresh', 5));
      const oldDirect = DirectConversation(
        id: 'dm1',
        participantId: 'u1',
        displayName: 'Old',
        unreadCount: 0,
      );
      final workspace = workspaceFor(api);
      addTearDown(workspace.dispose);
      workspace.directMessages = const [oldDirect];
      workspace.selectedDirectMessage = oldDirect;
      workspace.members = [
        revisionMember('Old', 4, presence: MemberPresence.offline),
      ];
      final profileUpdated = Completer<void>();

      expect(
        await dispatchMemberProfileUpdated(
          const RealtimeEvent('event-1', 'member.profile.updated', {
            'user_id': 'u1',
            'revision': 5,
          }),
          workspace,
          (userId, revision) {
            expect((userId, revision), ('u1', 5));
            profileUpdated.complete();
          },
        ),
        isTrue,
      );
      await profileUpdated.future;
      expect(api.reads, 1);
      expect(workspace.members.single.displayName, 'Fresh');
      expect(workspace.members.single.presence, MemberPresence.offline);
      expect(workspace.selectedDirectMessage?.displayName, 'Fresh');
      expect(api.directReads, 0);

      expect(
        await dispatchMemberProfileUpdated(
          const RealtimeEvent('event-2', 'member.profile.updated', {
            'user_id': 'u1',
            'revision': 6,
            'display_name': 'private data',
          }),
          workspace,
          (_, _) => fail('Invalid hint must not trigger profile refresh.'),
        ),
        isTrue,
      );
      expect(api.reads, 1);
    },
  );
}
