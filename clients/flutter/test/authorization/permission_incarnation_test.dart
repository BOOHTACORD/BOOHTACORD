import 'dart:async';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/controller.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingApi extends ApiClient {
  final requests = <Completer<PermissionSnapshot>>[];

  @override
  Future<PermissionSnapshot> loadPermissions() {
    final request = Completer<PermissionSnapshot>();
    requests.add(request);
    return request.future;
  }
}

PermissionSnapshot snapshot(int revision) => PermissionSnapshot(
  accountId: 'test-account',
  role: GuildRole.member,
  revision: revision,
  values: const {},
);

void main() {
  test('strict refresh supersedes an older pending snapshot', () async {
    final api = PendingApi();
    final controller = PermissionController(api, SessionScope());
    addTearDown(controller.dispose);
    final first = controller.start();
    final fresh = controller.refreshStrict();
    expect(api.requests, hasLength(2));
    api.requests[1].complete(snapshot(2));
    await fresh;
    api.requests[0].complete(snapshot(1));
    await first;
    expect(controller.snapshot?.revision, 2);
  });

  test('a response from an earlier session cannot update the new scope', () async {
    final api = PendingApi();
    final scope = SessionScope();
    final controller = PermissionController(api, scope);
    addTearDown(controller.dispose);
    final pending = controller.start();
    scope.begin();
    api.requests.single.complete(snapshot(1));
    await pending;
    expect(controller.snapshot, isNull);
  });

  test('a new session never reuses an earlier session request', () async {
    final api = PendingApi();
    final scope = SessionScope();
    final controller = PermissionController(api, scope);
    addTearDown(controller.dispose);
    final old = controller.start();
    scope.begin();
    final fresh = controller.refresh();
    expect(api.requests, hasLength(2));
    api.requests[1].complete(snapshot(2));
    await fresh;
    api.requests[0].complete(snapshot(1));
    await old;
    expect(controller.snapshot?.revision, 2);
  });

  test('strict refresh reports failure even if an old request succeeds', () async {
    final api = PendingApi();
    final controller = PermissionController(api, SessionScope());
    addTearDown(controller.dispose);
    final first = controller.start();
    final fresh = controller.refreshStrict();
    expect(api.requests, hasLength(2));
    api.requests[1].completeError(StateError('unavailable'));
    await expectLater(fresh, throwsStateError);
    api.requests[0].complete(snapshot(1));
    await first;
    expect(controller.snapshot, isNull);
  });
}
