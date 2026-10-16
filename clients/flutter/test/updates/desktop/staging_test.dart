import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/artifact.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/staging.dart';

import 'package_fixture.dart';

void main() {
  test(
    'local ZIP header name confusion is rejected before extraction',
    () async {
      final archive = Archive()..addFile(ArchiveFile('safe.txt', 3, [1, 2, 3]));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      bytes.setRange(30, 38, 'evil.txt'.codeUnits);
      final root = await Directory.systemTemp.createTemp('zip-name-test-');
      try {
        final file = await File('${root.path}/package').writeAsBytes(bytes);
        await expectLater(
          verifyAndExtract(
            file,
            Directory('${root.path}/payload'),
            await testPackage(bytes),
          ),
          throwsA(isA<ArtifactFailure>()),
        );
        expect(await Directory('${root.path}/payload').exists(), isFalse);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'a valid checked ZIP is extracted only after digest verification',
    () async {
      final archive = Archive()..addFile(ArchiveFile('safe.txt', 3, [1, 2, 3]));
      final bytes = ZipEncoder().encode(archive);
      final root = await Directory.systemTemp.createTemp('zip-valid-test-');
      try {
        final file = await File('${root.path}/package').writeAsBytes(bytes);
        await verifyAndExtract(
          file,
          Directory('${root.path}/payload'),
          await testPackage(bytes),
        );
        expect(await File('${root.path}/payload/safe.txt').readAsBytes(), [
          1,
          2,
          3,
        ]);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
