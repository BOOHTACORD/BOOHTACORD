import '../../workspace/lifecycle/controller.dart';
import '../lifecycle/event.dart';

Future<bool> dispatchPresence(
  RealtimeEvent event,
  WorkspaceController workspace,
) async {
  if (event.kind == 'presence.snapshot') {
    final ids = event.payload['online_user_ids'];
    final accepted = workspace.guildPresence.acceptSnapshot(ids, event.payload['idle_user_ids']);
    workspace.changed();
    if (accepted &&
        ids is List &&
        ids.any((id) => !workspace.members.any((member) => member.id == id))) {
      await workspace.refreshMembers();
    }
    return true;
  }
  if (event.kind != 'presence.changed') return false;
  final userId = event.payload['user_id'];
  final presence = event.payload['presence'];
  final accepted = workspace.guildPresence.acceptChange(userId, presence, event.payload['activity_state']);
  workspace.changed();
  if (accepted &&
      presence == 'online' &&
      userId is String &&
      !workspace.members.any((member) => member.id == userId)) {
    await workspace.refreshMemberProfile(userId, 0);
  }
  return true;
}
