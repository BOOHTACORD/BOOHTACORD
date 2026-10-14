import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/restore/checkpoint.dart';

void main() {
  late Directory root;
  late DesktopCheckpointStore store;
  final a = desktopScope('https://one.test', 'account'),
      b = desktopScope('https://two.test', 'account');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('desktop-checkpoint-test-');
    store = DesktopCheckpointStore(
      root,
      key: () async => SecretKey(List.filled(32, 1)),
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test(
    'workspace is encrypted, origin scoped and restart consumes exactly once',
    () async {
      final value = {
        'transaction': 'tx',
        'expected_release': 'release-2',
        'expected_build': '2',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(days: 1))
            .toIso8601String(),
        'drafts': [
          {'body': 'local private draft'},
        ],
      };
      await store.save(a, 'restart', value);
      expect(
        await File('${root.path}/$a-restart.json').readAsString(),
        isNot(contains('local private draft')),
      );
      expect(await store.read(b, 'restart'), isNull);
      expect(await store.consume(a, 'tx', 'release-1', '1'), isNull);
      expect(await store.consume(a, 'tx', 'release-2', '2'), isNotNull);
      expect(await store.consume(a, 'tx', 'release-2', '2'), isNull);
    },
  );
  test('rejects credentials and oversized data; corrupt checkpoint never blocks startup', () async {
    await expectLater(
      store.save(a, 'workspace', {'access_token': 'never-copy'}),
      throwsFormatException,
    );
    await expectLater(
      store.save(a, 'workspace', {'draft': 'x' * (1024 * 1024 + 1)}),
      throwsFormatException,
    );
    await File('${root.path}/$a-workspace.json').writeAsString('corrupt');
    expect(await store.read(a, 'workspace'), isNull);
  });
}
