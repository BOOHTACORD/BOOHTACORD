import 'package:boohtacord_desktop/src/features/realtime/dispatch/presence.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';
import 'package:boohtacord_desktop/src/features/workspace/load_members/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'member_profile_fakes.dart';

class SnapshotApi extends ImmediateMemberProfileApi {
  SnapshotApi(super.result);
  int lists = 0;
  @override
  Future<List<GuildMember>> members() async {
    lists++;
    return [result];
  }
}

void main() {
  test('snapshot reconciles members who arrived while disconnected', () async {
    const id = '11111111-1111-4111-8111-111111111111';
    final api = SnapshotApi(
      const GuildMember(
        id: id,
        login: 'new',
        displayName: 'New',
        role: 'MEMBER',
        presence: MemberPresence.online,
      ),
    );
    final workspace = workspaceFor(api);
    addTearDown(workspace.dispose);
    expect(
      await dispatchPresence(
        const RealtimeEvent('snapshot', 'presence.snapshot', {
          'online_user_ids': [id],
        }),
        workspace,
      ),
      isTrue,
    );
    expect(workspace.members.single.id, id);
    expect(api.lists, 1);
  });
  test('online presence loads a previously unknown member once', () async {
    const id = '11111111-1111-4111-8111-111111111111';
    final api = ImmediateMemberProfileApi(
      const GuildMember(
        id: id,
        login: 'new',
        displayName: 'New member',
        role: 'MEMBER',
        presence: MemberPresence.online,
      ),
    );
    final workspace = workspaceFor(api);
    addTearDown(workspace.dispose);
    const event = RealtimeEvent('event', 'presence.changed', {
      'user_id': id,
      'presence': 'online',
    });
    expect(await dispatchPresence(event, workspace), isTrue);
    expect(workspace.members.single.id, id);
    expect(
      workspace.memberPresence(workspace.members.single),
      MemberPresence.online,
    );
    expect(await dispatchPresence(event, workspace), isTrue);
    expect(api.reads, 1);
    expect(
      await dispatchPresence(
        const RealtimeEvent('bad', 'presence.changed', {
          'user_id': 'invalid',
          'presence': 'online',
        }),
        workspace,
      ),
      isTrue,
    );
    expect(api.reads, 1);
  });
}
