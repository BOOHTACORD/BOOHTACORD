import 'dart:async';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/profile/revision/cache.dart';
import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

WorkspaceController workspaceFor(ApiClient api) => WorkspaceController(
  api,
  SessionScope(),
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

GuildMember revisionMember(
  String name,
  int revision, {
  MemberPresence presence = MemberPresence.unknown,
}) {
  final member = GuildMember(
    id: 'u1',
    login: 'login',
    displayName: name,
    role: 'MEMBER',
    presence: presence,
  );
  memberProfileRevisions.recordMember(member, revision);
  return member;
}

class DelayedMemberProfileApi extends ApiClient {
  final reads = <Completer<GuildMember>>[];

  @override
  Future<GuildMember> memberProfile(String accountId) {
    final result = Completer<GuildMember>();
    reads.add(result);
    return result.future;
  }
}

class ImmediateMemberProfileApi extends ApiClient {
  ImmediateMemberProfileApi(this.result);
  final GuildMember result;
  int reads = 0;
  int directReads = 0;

  @override
  Future<GuildMember> memberProfile(String accountId) async {
    reads++;
    return result;
  }

  @override
  Future<List<DirectConversation>> directMessages() async {
    directReads++;
    return const [];
  }
}

class StaleMembersApi extends ApiClient {
  StaleMembersApi(this.result);
  final List<GuildMember> result;

  @override
  Future<List<GuildMember>> members() async => result;
}
