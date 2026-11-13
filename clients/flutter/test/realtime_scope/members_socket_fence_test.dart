import 'dart:async';

import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../voice_roster_state/app_support.dart';
import '../voice_roster_state/support.dart';

class PendingMembersApi extends RosterApi {
  final requests = <Completer<List<GuildMember>>>[];
  @override
  Future<List<GuildMember>> members() {
    final request = Completer<List<GuildMember>>();
    requests.add(request);
    return request.future;
  }
}

const oldMember = GuildMember(id: 'old', login: 'old', displayName: 'Old',
    role: 'MEMBER', presence: MemberPresence.unknown);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('socket end fences an in-flight realtime member response', () async {
    final api = PendingMembersApi(), state = ready(api);
    state.realtime.socketAttempt.begin();
    final old = state.workspace.refreshMembers(strict: true);
    await state.realtime.close();
    expect(state.workspace.membersLoading, isFalse);
    api.requests.single.complete([oldMember]);
    await old;
    expect(state.workspace.members, isEmpty);
    expect(state.workspace.membersLoading, isFalse);
  });

  test('late old members cannot replace the new socket result', () async {
    final api = PendingMembersApi(), state = ready(api);
    state.realtime.socketAttempt.begin();
    final old = state.workspace.refreshMembers(strict: true);
    await state.realtime.close();
    state.realtime.socketAttempt.begin();
    final fresh = state.workspace.refreshMembers(strict: true);
    api.requests[1].complete([]);
    await fresh;
    api.requests[0].complete([oldMember]);
    await old;
    expect(state.workspace.members, isEmpty);
  });

  test('independent initial member loading survives socket end', () async {
    final api = PendingMembersApi(), state = ready(api);
    final initial = state.workspace.refreshMembers();
    state.realtime.socketAttempt.begin();
    await state.realtime.close();
    api.requests.single.complete([oldMember]);
    await initial;
    expect(state.workspace.members, [oldMember]);
  });

  test('an old failure cannot replace the new owner state', () async {
    final api = PendingMembersApi(), state = ready(api);
    state.realtime.socketAttempt.begin();
    final old = state.workspace.refreshMembers(strict: true);
    await state.realtime.close();
    api.requests.single.completeError(StateError('old request failed'));
    await old;
    expect(state.workspace.membersError, isNull);
    expect(state.workspace.membersLoading, isFalse);
  });
}
