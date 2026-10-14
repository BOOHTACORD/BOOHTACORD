import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/local_feed.dart';

void main() {
  test(
    'loopback feed exposes only selected archive under unguessable route',
    () async {
      final root = await Directory.systemTemp.createTemp('desktop-feed-');
      final file = await File('${root.path}/package.zip')
          .writeAsBytes([1, 2, 3]);
      final feed = await SelectedPackageFeed.start(
        file,
        build: '2',
        version: '1.0.2',
        signature: 'signed-archive',
      );
      final client = HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttp());
      try {
        final response = await (await client.getUrl(feed.archiveUrl)).close();
        expect(response.statusCode, 200);
        expect(await response.fold<List<int>>([], (a, b) => a..addAll(b)), [
          1,
          2,
          3,
        ]);
        final missing = await (await client.getUrl(
          feed.archiveUrl.resolve('/package.zip'),
        )).close();
        expect(missing.statusCode, 404);
        await missing.drain<void>();
        final appcast = await (await client.getUrl(feed.feedUrl)).close();
        final data = await appcast.transform(SystemEncoding().decoder).join();
        expect(data, contains('sparkle:version="2"'));
        expect(data, contains(feed.archiveUrl.toString()));
      } finally {
        client.close(force: true);
        await feed.close();
        await root.delete(recursive: true);
      }
    },
  );
}

class _RealHttp extends HttpOverrides {}
