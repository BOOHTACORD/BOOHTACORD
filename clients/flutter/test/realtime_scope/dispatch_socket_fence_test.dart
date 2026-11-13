import 'dart:async';

import 'package:boohtacord_desktop/src/features/guild/profile/model.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../voice_roster_state/app_support.dart';
import '../voice_roster_state/support.dart';

class RecoveryApi extends RosterApi {
  Completer<GuildProfile>? profileGate;
  Completer<ChannelTopology>? topologyGate;
  int topologyReads = 0, memberReads = 0, directReads = 0, permissionReads = 0;

  @override
  Future<GuildProfile> guildProfile() => profileGate?.future ?? Future.value(const GuildProfile('QA', 1));
  @override
  Future<ChannelTopology> topology() {
    topologyReads++;
    return topologyGate?.future ?? Future.value(const ChannelTopology(revision: 1, categories: []));
  }
  @override
  Future<List<GuildMember>> members() async { memberReads++; return []; }
  @override
  Future<List<DirectConversation>> directMessages() async { directReads++; return []; }
  @override
  Future<PermissionSnapshot> loadPermissions() async {
    permissionReads++;
    return const PermissionSnapshot(accountId: 'account-1', role: GuildRole.member, revision: 1, values: {});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('old recovery cannot start topology after socket closes during guild load', () async {
    final api = RecoveryApi()..profileGate = Completer<GuildProfile>();
    final state = ready(api);
    state.realtime.socketAttempt.begin();
    final pending = Future<void>.sync(() => state.realtime.dispatch(
      const RealtimeEvent('old', 'connection.resync_required', {})));
    await state.realtime.close();
    api.profileGate!.complete(const GuildProfile('QA', 1));
    await pending;
    expect(api.topologyReads, 0);
  });

  test('old recovery cannot start dependent loads after topology returns', () async {
    final api = RecoveryApi()..topologyGate = Completer<ChannelTopology>();
    final state = ready(api);
    state.realtime.socketAttempt.begin();
    final pending = Future<void>.sync(() => state.realtime.dispatch(
      const RealtimeEvent('old', 'connection.resync_required', {})));
    while (api.topologyReads == 0) { await Future<void>.delayed(Duration.zero); }
    await state.realtime.close();
    api.topologyGate!.complete(const ChannelTopology(revision: 1, categories: []));
    await pending;
    expect(api.memberReads, 0);
    expect(api.directReads, 0);
  });

  test('old ready cannot start a permissions refresh after socket closes', () async {
    final api = RecoveryApi()..profileGate = Completer<GuildProfile>();
    final state = ready(api);
    await state.permissions.start();
    state.realtime.socketAttempt.begin();
    final pending = Future<void>.sync(() => state.realtime.dispatch(
      const RealtimeEvent('old', 'connection.ready', {})));
    await state.realtime.close();
    api.profileGate!.complete(const GuildProfile('QA', 1));
    await pending;
    expect(api.permissionReads, 1);
  });

  test('current ready still refreshes permissions', () async {
    final api = RecoveryApi(), state = ready(api);
    await state.permissions.start();
    state.realtime.socketAttempt.begin();
    await state.realtime.dispatch(const RealtimeEvent('ready', 'connection.ready', {}));
    expect(api.permissionReads, 2);
  });
}
