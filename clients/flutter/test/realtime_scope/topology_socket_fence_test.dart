import 'dart:async';

import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../voice_roster_state/app_support.dart';
import '../voice_roster_state/support.dart';

class PendingTopologyApi extends RosterApi {
  final requests = <Completer<ChannelTopology>>[];
  @override
  Future<ChannelTopology> topology() {
    final request = Completer<ChannelTopology>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('socket end fences a realtime topology response before reconnect', () async {
    final api = PendingTopologyApi(), state = ready(api);
    state.realtime.onSocketStart?.call();
    final old = state.workspace.refreshTopology(strict: true);
    state.realtime.onSocketEnd?.call();
    api.requests.single.complete(const ChannelTopology(revision: 1, categories: []));
    await old;
    expect(state.workspace.topology, isNull);
  });

  test('a late realtime topology response cannot replace a newer result', () async {
    final api = PendingTopologyApi(), state = ready(api);
    state.realtime.onSocketStart?.call();
    final old = state.workspace.refreshTopology(strict: true);
    state.realtime.onSocketEnd?.call();
    state.realtime.onSocketStart?.call();
    final fresh = state.workspace.refreshTopology(strict: true);
    api.requests[1].complete(const ChannelTopology(revision: 2, categories: []));
    await fresh;
    api.requests[0].complete(const ChannelTopology(revision: 1, categories: []));
    await old;
    expect(state.workspace.topology?.revision, 2);
  });

  test('socket end does not discard independent initial topology loading', () async {
    final api = PendingTopologyApi(), state = ready(api);
    final initial = state.workspace.refreshTopology();
    state.realtime.onSocketStart?.call();
    state.realtime.onSocketEnd?.call();
    api.requests.single.complete(const ChannelTopology(revision: 1, categories: []));
    await initial;
    expect(state.workspace.topology?.revision, 1);
  });

  test('a stale topology failure does not report an error to the new owner', () async {
    final api = PendingTopologyApi(), state = ready(api);
    state.realtime.onSocketStart?.call();
    final old = state.workspace.refreshTopology(strict: true);
    state.realtime.onSocketEnd?.call();
    api.requests.single.completeError(StateError('old request failed'));
    await old;
    expect(state.workspace.topology, isNull);
  });
}
