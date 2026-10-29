import 'dart:async';

import 'package:boohtacord_desktop/src/features/conversation/lifecycle/controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('never-completing canonical GET times out; retry never reposts', (
    tester,
  ) async {
    final never = Completer<http.Response>();
    final f = SendFixture()..historyGate = never;
    addTearDown(f.dispose);
    final sending = f.send();
    await tester.pump();
    expect(f.historyReads, 1);
    expect(never.isCompleted, isFalse);
    expect(f.state.sending, isTrue);
    await tester.pump(const Duration(seconds: 21));
    expect(f.state.sending, isFalse);
    expect(await sending, isFalse);
    expect(
      f.state.directMessageHistory.single.sendStatus,
      MessageSendStatus.failed,
    );
    final client = f.clientId!;
    f.historyGate = null;
    expect(await f.state.retryDirectSend(client), isTrue);
    expect(f.posts, 1);
    expect(f.clientId, client);
    expect(
      f.state.directMessageHistory.single.attachments.single.id,
      f.file.id,
    );
    f.state.session.scope.begin();
    f.state.conversation.clear();
    never.complete(
      f.response({
        'messages': [f.row()],
      }),
    );
    await tester.pump();
    expect(f.state.directMessageHistory, isEmpty);
    expect(f.state.sending, isFalse);
  });
}
