import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final extension in ['jpg', 'gif']) {
    for (final emptyAck in [false, true]) {
      test(
        'own $extension survives minimal201 empty=$emptyAck without realtime',
        () async {
          final f = SendFixture(extension: extension, emptyAck: emptyAck);
          addTearDown(f.dispose);
          expect(await f.send(), isTrue);
          final row = f.state.directMessageHistory.single;
          expect(row.attachments.map((file) => file.id), [f.file.id]);
          expect(row.attachments.single.originalName, f.file.originalName);
          expect(row.id, 'stored');
          expect(row.sendStatus, isNull);
          expect(f.posts, 1);
          expect(f.historyReads, 1);
          expect(f.state.realtime.connected, isFalse);
        },
      );
    }
  }
}
