import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/baseline.dart';

void main() {
  test(
    'baseline retains the whole installed tree with verified per-file hashes',
    () async {
      final root = await Directory.systemTemp.createTemp('desktop-baseline-');
      try {
        final current = await Directory('${root.path}/current').create();
        await Directory('${current.path}/data').create();
        await File('${current.path}/boohtacord_desktop.exe')
            .writeAsBytes([1, 2, 3]);
        await File('${current.path}/data/asset').writeAsBytes([4, 5]);
        final recovery = await Directory('${root.path}/recovery').create();
        await retainWindowsBaseline(current, recovery);
        final manifest = jsonDecode(
          await File('${recovery.path}/baseline.json').readAsString(),
        );
        expect((manifest['files'] as Map).keys.toSet(), {
          'boohtacord_desktop.exe',
          'data/asset',
        });
        expect(
          manifest['files']['data/asset'],
          crypto.sha256.convert([4, 5]).toString(),
        );
        expect(
          await File('${recovery.path}/previous/data/asset').readAsBytes(),
          [4, 5],
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
