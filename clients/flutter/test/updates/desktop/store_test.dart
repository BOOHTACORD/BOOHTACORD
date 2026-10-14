import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/staging.dart';

void main() {
  test(
    'one writer across stores, queued journals retain monotonic order',
    () async {
      final root = await Directory.systemTemp.createTemp('desktop-store-');
      final a = DesktopUpdateStore(root), b = DesktopUpdateStore(root);
      try {
        expect(await a.acquireWriter(), isTrue);
        expect(await b.acquireWriter(), isFalse);
        await Future.wait([
          a.writeJournal({'highest_order': 4, 'phase': 'readyToRestart'}),
          a.writeJournal({'highest_order': 3, 'phase': 'completed'}),
        ]);
        expect((await a.readJournal())!['highest_order'], 4);
        await a.releaseWriter();
        expect(await b.acquireWriter(), isTrue);
      } finally {
        await a.releaseWriter();
        await b.releaseWriter();
        await root.delete(recursive: true);
      }
    },
  );
}
