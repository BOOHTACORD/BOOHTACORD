import 'dart:async';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/text/system_welcome/lookup.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedApi extends ApiClient {
  final calls = <Completer<GuildMember>>[];
  @override
  Future<GuildMember> memberProfile(String id) {
    final c = Completer<GuildMember>();
    calls.add(c);
    return c.future;
  }
}

void main() {
  test(
    'coalesces one author per session but separates a replaced session',
    () async {
      final api = DelayedApi();
      final scope = SessionScope();
      const id = 'user';
      final first = loadWelcomeAuthor(scope, api, id);
      final same = loadWelcomeAuthor(scope, api, id);
      expect(api.calls.length, 1);
      scope.begin();
      final later = loadWelcomeAuthor(scope, api, id);
      expect(api.calls.length, 2);
      const old = GuildMember(
        id: id,
        login: 'old',
        displayName: 'Old',
        role: 'MEMBER',
        presence: MemberPresence.offline,
      );
      const fresh = GuildMember(
        id: id,
        login: 'new',
        displayName: 'New',
        role: 'MEMBER',
        presence: MemberPresence.offline,
      );
      api.calls[0].complete(old);
      api.calls[1].complete(fresh);
      expect((await first).displayName, 'Old');
      expect((await same).displayName, 'Old');
      expect((await later).displayName, 'New');
    },
  );
}
