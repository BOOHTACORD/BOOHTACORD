import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'known201 readback failure retries checking with no second POST',
    () async {
      final f = SendFixture()
        ..historyError = const ApiFailure('offline', status: 503);
      addTearDown(f.dispose);
      expect(await f.send(), isFalse);
      final client = f.clientId!;
      expect(
        f.historyReads,
        1,
        reason: 'hydration is outside uncertain POST recovery',
      );
      expect(
        f.state.directMessageHistory.single.sendStatus,
        MessageSendStatus.failed,
      );
      expect(await f.state.retryDirectSend(client), isFalse);
      expect(f.posts, 1);
      expect(f.historyReads, 2);
      f.historyError = null;
      expect(await f.state.retryDirectSend(client), isTrue);
      expect(f.posts, 1);
      expect(f.clientId, client);
      expect(
        f.state.directMessageHistory.single.attachments.single.id,
        f.file.id,
      );
    },
  );
  test(
    'body-only direct send remains one POST without metadata lookup',
    () async {
      final f = SendFixture();
      addTearDown(f.dispose);
      expect(await f.state.sendDirect('hello'), isTrue);
      expect(f.posts, 1);
      expect(f.historyReads, 0);
      expect(f.state.directMessageHistory.single.body, 'hello');
    },
  );
  test('discarding failed own optimistic row remains local', () async {
    final f = SendFixture()
      ..historyError = const ApiFailure('offline', status: 503);
    addTearDown(f.dispose);
    expect(await f.send(), isFalse);
    await f.state.deleteDirect(f.state.directMessageHistory.single);
    expect(f.state.directMessageHistory, isEmpty);
    expect(f.posts, 1);
  });
}
