import 'dart:async';

import 'package:boohtacord_desktop/src/features/conversation/lifecycle/controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final deleted in [false, true]) {
    test(
      'newer applied row deleted=$deleted wins late canonical GET',
      () async {
        final f = SendFixture()..historyGate = Completer<http.Response>();
        addTearDown(f.dispose);
        final sending = f.send();
        await f.historyRequested.future.timeout(const Duration(seconds: 2));
        final current = DirectChatMessage.fromJson({
          ...f.row(),
          'body': deleted ? '' : 'newer edit',
          'revision': 3,
          'deleted': deleted,
          if (deleted) 'attachments': [],
        });
        f.state.conversation.directMessageHistory = [current];
        f.historyGate!.complete(
          f.response({
            'messages': [f.row()],
          }),
        );
        expect(await sending, isTrue);
        final accepted = f.state.directMessageHistory.single;
        expect(accepted.revision, 3);
        expect(accepted.deleted, deleted);
        expect(accepted.body, current.body);
        if (deleted) expect(accepted.attachments, isEmpty);
      },
    );
  }
  test('late canonical cannot cross session replacement', () async {
    final f = SendFixture()..historyGate = Completer<http.Response>();
    addTearDown(f.dispose);
    final sending = f.send();
    await f.historyRequested.future.timeout(const Duration(seconds: 2));
    f.state.session.scope.begin();
    f.state.conversation.clear();
    f.historyGate!.complete(
      f.response({
        'messages': [f.row()],
      }),
    );
    expect(await sending, isFalse);
    expect(f.state.directMessageHistory, isEmpty);
    expect(f.posts, 1);
  });
}
