import 'dart:async';

import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../voice_roster_state/app_support.dart';
import '../voice_roster_state/support.dart';

class PendingPermissionApi extends RosterApi {
  final requests = <Completer<PermissionSnapshot>>[];

  @override
  Future<PermissionSnapshot> loadPermissions() {
    final request = Completer<PermissionSnapshot>();
    requests.add(request);
    return request.future;
  }
}

PermissionSnapshot snapshot(int revision) => PermissionSnapshot(
  accountId: 'account-1',
  role: GuildRole.member,
  revision: revision,
  values: const {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('socket end fences an already running realtime permission refresh', () async {
    final api = PendingPermissionApi();
    final state = ready(api);
    final initial = state.permissions.start();
    api.requests[0].complete(snapshot(1));
    await initial;
    state.realtime.onSocketStart?.call();
    final pending = state.permissions.refreshStrict();
    final rejected = expectLater(pending, throwsStateError);
    state.realtime.onSocketEnd?.call();
    api.requests[1].complete(snapshot(2));
    await rejected;
    expect(state.permissions.snapshot?.revision, 1);
    expect(state.permissions.loading, isFalse);
  });

  test('socket end does not cancel an independent initial permission load', () async {
    final api = PendingPermissionApi();
    final state = ready(api);
    final initial = state.permissions.start();
    state.realtime.onSocketStart?.call();
    state.realtime.onSocketEnd?.call();
    api.requests.single.complete(snapshot(1));
    await initial;
    expect(state.permissions.snapshot?.revision, 1);
  });
}
