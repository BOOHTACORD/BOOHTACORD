import 'dart:async';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final duringPost in [true, false]) {
    test(
      'navigate during ${duringPost ? 'POST' : 'hydration'} preserves other DM',
      () async {
        final f = SendFixture()..historyGate = Completer<http.Response>();
        if (duringPost) f.postGate = Completer<http.Response>();
        addTearDown(f.dispose);
        final sending = f.send();
        await (duringPost ? f.postRequested.future : f.historyRequested.future)
            .timeout(const Duration(seconds: 2));
        const other = DirectConversation(
          id: 'other-pair',
          participantId: 'other-peer',
          displayName: 'Other',
          unreadCount: 0,
        );
        final existing = DirectChatMessage(
          id: 'other-message',
          directMessageId: other.id,
          authorId: 'other-peer',
          body: 'preserved',
          createdAt: DateTime.utc(2026),
          deleted: false,
          revision: 1,
        );
        f.state.workspace.selectedDirectMessage = other;
        f.state.conversation.directMessageHistory = [existing];
        if (duringPost) {
          f.postGate!.complete(f.response(f.row(attachments: false), 201));
          await f.historyRequested.future.timeout(const Duration(seconds: 2));
        }
        expect(f.state.directMessageHistory, [existing]);
        f.historyGate!.complete(
          f.response({
            'messages': [f.row()],
          }),
        );
        expect(await sending, isTrue);
        expect(f.state.directMessageHistory, [existing]);
        expect(f.posts, 1);
      },
    );
  }
}
