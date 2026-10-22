import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/direct/conversations/support_contact.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

const peer = '22222222-2222-4222-8222-222222222222';
const pair = DirectConversation(
  id: 'pair',
  participantId: peer,
  displayName: 'Оператор',
  unreadCount: 0,
);

class SupportApi extends ApiClient {
  SupportContact contact = const SupportContact(
    state: 'available',
    revision: 1,
    accountId: peer,
  );
  bool opened = false;
  int writes = 0;
  String? target;
  Completer<String>? pending;
  @override
  Future<List<DirectConversation>> directMessages() async =>
      DirectNavigation(opened ? [pair] : [], support: contact);
  @override
  Future<List<DirectCandidate>> directMessageCandidates() async => [];
  @override
  Future<String> openDirectMessage(String id) async {
    writes++;
    target = id;
    opened = true;
    return pending == null ? 'pair' : pending!.future;
  }
}

WorkspaceController controller(
  SupportApi api,
  SessionScope scope,
  List<String> opened,
) => WorkspaceController(
  api,
  scope,
  effects: WorkspaceEffects(
    selectChannel: (_) async {},
    openDirect: (value) async => opened.add(value.id),
    invalidateText: () {},
    clearText: () {},
    clearDirect: () {},
    error: (_) {},
    message: (_) => 'safe failure',
  ),
);
void main() {
  test('support is opened with the ordinary account pair and reused', () async {
    final api = SupportApi();
    final selected = <String>[];
    final c = controller(api, SessionScope(), selected);
    addTearDown(c.dispose);
    expect(await c.openSupport(), isTrue);
    expect(api.target, peer);
    expect(c.directDisplayName(pair), 'Поддержка');
    expect(selected, ['pair']);
    expect(await c.openSupport(), isTrue);
    expect(selected, ['pair', 'pair']);
  });
  test('self and unconfigured contacts do not send requests', () async {
    final api = SupportApi();
    final c = controller(api, SessionScope(), []);
    addTearDown(c.dispose);
    for (final state in ['self', 'not_configured', 'unavailable']) {
      api.contact = SupportContact(state: state, revision: 1);
      expect(await c.openSupport(), isFalse);
    }
    expect(api.writes, 0);
  });
  test(
    'account replacement cannot reopen the old support conversation',
    () async {
      final api = SupportApi()..pending = Completer<String>();
      final scope = SessionScope();
      final selected = <String>[];
      final c = controller(api, scope, selected);
      addTearDown(c.dispose);
      final work = c.openSupport();
      while (api.writes == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      scope.close();
      c.clear();
      scope.begin();
      api.pending!.complete('pair');
      expect(await work, isFalse);
      expect(selected, isEmpty);
      expect(c.supportContact.accountId, isNull);
    },
  );
}
