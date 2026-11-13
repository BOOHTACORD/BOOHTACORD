import 'dart:async';

import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../voice_roster_state/app_support.dart';
import '../voice_roster_state/support.dart';

class PendingDirectsApi extends RosterApi {
  final requests = <Completer<List<DirectConversation>>>[];
  final candidates = Completer<List<DirectCandidate>>();
  @override
  Future<List<DirectConversation>> directMessages() {
    final request = Completer<List<DirectConversation>>();
    requests.add(request);
    return request.future;
  }
  @override
  Future<List<DirectCandidate>> directMessageCandidates() => candidates.future;
}

const oldDirect = DirectConversation(id: 'old', participantId: 'other',
    displayName: 'Old', unreadCount: 0);
const oldCandidate = DirectCandidate(id: 'old', displayName: 'Old');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('socket end fences an in-flight realtime direct list', () async {
    final api = PendingDirectsApi(), state = ready(api);
    state.realtime.socketAttempt.begin();
    final old = state.workspace.refreshDirectMessages(strict: true);
    await state.realtime.close();
    api.requests.single.complete([oldDirect]);
    await old;
    expect(state.workspace.directMessages, isEmpty);
  });

  test('independent initial direct loading survives socket end', () async {
    final api = PendingDirectsApi(), state = ready(api);
    final initial = state.workspace.refreshDirectMessages();
    state.realtime.socketAttempt.begin();
    await state.realtime.close();
    api.requests.single.complete([oldDirect]);
    await initial;
    expect(state.workspace.directMessages, [oldDirect]);
  });

  test('late candidates from a closed socket cannot update the new owner', () async {
    final api = PendingDirectsApi(), state = ready(api);
    state.workspace.navigationSection = NavigationSection.directMessages;
    state.realtime.socketAttempt.begin();
    final old = state.workspace.refreshDirectMessages(strict: true);
    api.requests.single.complete([]);
    await Future<void>.delayed(Duration.zero);
    await state.realtime.close();
    api.candidates.complete([oldCandidate]);
    await old;
    expect(state.workspace.directMessageCandidates, isEmpty);
  });

  test('stale direct-list failure does not affect a new owner', () async {
    final api = PendingDirectsApi(), state = ready(api);
    state.realtime.socketAttempt.begin();
    final old = state.workspace.refreshDirectMessages(strict: true);
    await state.realtime.close();
    api.requests.single.completeError(StateError('old request failed'));
    await old;
    expect(state.workspace.directMessages, isEmpty);
  });
}
