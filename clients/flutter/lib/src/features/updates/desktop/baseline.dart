import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;

import 'artifact.dart';

/// Preserve only the currently executing installed image, including every DLL.
/// The native monitor authenticates this local manifest again before rollback.
Future<void> retainWindowsBaseline(
  Directory current,
  Directory recovery,
) async {
  final backup = Directory(path.join(recovery.path, 'previous'));
  final files = <String, String>{};
  var total = 0;
  Future<void> copy(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entry in source.list(followLinks: false)) {
      final target = path.join(destination.path, path.basename(entry.path));
      if (entry is File) {
        total += await entry.length();
        if (total > 2 * 1024 * 1024 * 1024 || files.length >= 5000) {
          throw const ArtifactFailure('recovery_size');
        }
        final expected = (await crypto.sha256.bind(entry.openRead()).first)
            .toString();
        final file = await entry.copy(target);
        if ((await crypto.sha256.bind(file.openRead()).first).toString() !=
            expected) {
          throw const ArtifactFailure('recovery_copy');
        }
        files[path.relative(target, from: backup.path).replaceAll('\\', '/')] =
            expected;
      } else if (entry is Directory) {
        await copy(entry, Directory(target));
      } else {
        throw const ArtifactFailure('recovery_link');
      }
    }
  }

  await copy(current, backup);
  final manifest = jsonEncode({'schema_version': 1, 'files': files});
  if (manifest.length > 2 * 1024 * 1024) {
    throw const ArtifactFailure('recovery_size');
  }
  await File(path.join(recovery.path, 'baseline.json'))
      .writeAsString(manifest, flush: true);
}
