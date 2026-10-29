import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final field in [
    'id',
    'client_message_id',
    'author_id',
    'direct_message_id',
  ]) {
    test('canonical mismatched $field never becomes confirmed', () async {
      final f = SendFixture()..canonicalChanges[field] = 'unrelated';
      addTearDown(f.dispose);
      expect(await f.send(), isFalse);
      expect(f.posts, 1);
      expect(f.historyReads, 1);
      final pending = f.state.directMessageHistory.single;
      expect(pending.id, startsWith('optimistic:'));
      expect(pending.sendStatus, MessageSendStatus.failed);
      expect(pending.authorId, 'owner');
      expect(pending.directMessageId, pair.id);
    });
  }
  for (final field in ['author_id', 'client_message_id', 'direct_message_id']) {
    test(
      'wrong acknowledgement $field stops before canonical lookup',
      () async {
        final f = SendFixture()..ackChanges[field] = 'unrelated';
        addTearDown(f.dispose);
        expect(await f.send(), isFalse);
        expect(f.posts, 1);
        expect(f.historyReads, 0);
        expect(f.receipts, 0);
      },
    );
  }
  test(
    'incomplete canonical metadata stays failed instead of fabricated',
    () async {
      final f = SendFixture()..canonicalChanges['attachments'] = [];
      addTearDown(f.dispose);
      expect(await f.send(), isFalse);
      expect(
        f.state.directMessageHistory.single.sendStatus,
        MessageSendStatus.failed,
      );
      expect(f.state.directMessageHistory.single.id, startsWith('optimistic:'));
    },
  );
  test(
    'canonical tombstone is accepted without restoring draft files',
    () async {
      final f = SendFixture()
        ..canonicalChanges.addAll({
          'deleted': true,
          'revision': 2,
          'attachments': [],
        });
      addTearDown(f.dispose);
      expect(await f.send(), isTrue);
      final row = f.state.directMessageHistory.single;
      expect(row.deleted, isTrue);
      expect(row.attachments, isEmpty);
      expect(row.revision, 2);
    },
  );
}
