import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class DelayedWorkspaceApi extends ApiClient {
  final result = Completer<List<GuildMember>>();
  @override
  Future<List<GuildMember>> members() => result.future;
}

void main() {
  test('late member list is discarded across account replacement', () async {
    final api = DelayedWorkspaceApi();
    final scope = SessionScope();
    final workspace = WorkspaceController(
      api,
      scope,
      effects: WorkspaceEffects(
        selectChannel: (_, {socketCurrent}) async {},
        openDirect: (_) async {},
        invalidateText: () {},
        clearText: () {},
        clearDirect: () {},
        error: (_) {},
        message: (cause) => cause.toString(),
      ),
    );
    addTearDown(workspace.dispose);
    final loading = workspace.refreshMembers();
    scope.close();
    workspace.clear();
    scope.begin();
    api.result.complete([
      const GuildMember(
        id: 'old',
        login: 'old',
        displayName: 'Old account',
        role: 'MEMBER',
        presence: MemberPresence.online,
      ),
    ]);
    await loading;
    expect(workspace.members, isEmpty);
    expect(workspace.membersLoading, isFalse);
  });
}
