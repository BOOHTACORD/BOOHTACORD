import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;

import 'artifact.dart';
import 'archive_policy.dart';

Future<void> verifyPackageDigest(
  File package,
  VerifiedInstallArtifact artifact,
) async {
  final input = package.path, size = artifact.size, digest = artifact.sha256;
  await Isolate.run(() async {
    final file = File(input);
    if (!await file.exists() ||
        await file.length() != size ||
        (await crypto.sha256.bind(file.openRead()).first).toString() !=
            digest) {
      throw const ArtifactFailure('digest');
    }
  });
}

Future<void> verifyAndExtract(
  File package,
  Directory destination,
  VerifiedInstallArtifact artifact,
) async {
  final input = package.path,
      output = destination.path,
      expectedSize = artifact.size,
      expectedHash = artifact.sha256;
  final macos = artifact.packageType == 'sparkle_zip';
  await Isolate.run(() async {
    final file = File(input);
    if (await file.length() != expectedSize ||
        (await crypto.sha256.bind(file.openRead()).first).toString() !=
            expectedHash) {
      throw const ArtifactFailure('digest');
    }
    await _scanZip(file);
    final stream = InputFileStream(input);
    try {
      final archive = ZipDecoder().decodeStream(stream);
      validateUpdateArchive(archive, macos: macos);
      final directory = Directory(output);
      if (await directory.exists()) await directory.delete(recursive: true);
      await directory.create(recursive: true);
      if (macos) {
        final result = await Process.run('/usr/bin/ditto', [
          '-x',
          '-k',
          input,
          output,
        ]);
        if (result.exitCode != 0) throw const ArtifactFailure('extraction');
      } else {
        await extractArchiveToDisk(archive, output);
      }
    } finally {
      stream.close();
    }
  });
}

Future<void> _scanZip(File file) async {
  final io = await file.open();
  try {
    final length = await io.length(),
        tailLength = length < 65557 ? length : 65557;
    await io.setPosition(length - tailLength);
    final tail = await io.read(tailLength);
    var end = -1;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (tail[i] == 0x50 &&
          tail[i + 1] == 0x4b &&
          tail[i + 2] == 5 &&
          tail[i + 3] == 6) {
        end = i;
        break;
      }
    }
    if (end < 0) throw const ArtifactFailure('archive_directory');
    final footer = ByteData.sublistView(Uint8List.fromList(tail), end);
    final count = footer.getUint16(10, Endian.little),
        size = footer.getUint32(12, Endian.little),
        offset = footer.getUint32(16, Endian.little);
    if (footer.getUint16(4, Endian.little) != 0 ||
        footer.getUint16(6, Endian.little) != 0 ||
        count == 0 ||
        count > 50000 ||
        size > 16 * 1024 * 1024 ||
        offset + size > length - tailLength + end) {
      throw const ArtifactFailure('archive_directory');
    }
    await io.setPosition(offset);
    final central = ByteData.sublistView(await io.read(size));
    var cursor = 0, total = 0;
    for (var n = 0; n < count; n++) {
      if (cursor + 46 > central.lengthInBytes ||
          central.getUint32(cursor, Endian.little) != 0x02014b50) {
        throw const ArtifactFailure('archive_directory');
      }
      final declared = central.getUint32(cursor + 24, Endian.little),
          attributes = central.getUint32(cursor + 38, Endian.little);
      total += declared;
      if (declared > 1024 * 1024 * 1024 ||
          total > 2 * 1024 * 1024 * 1024 ||
          (central.getUint16(cursor + 8, Endian.little) & 1) != 0 ||
          (((attributes >> 16) & 0xf000) == 0xa000 && declared > 1024)) {
        throw const ArtifactFailure('archive_size');
      }
      final nameSize = central.getUint16(cursor + 28, Endian.little),
          extraSize = central.getUint16(cursor + 30, Endian.little);
      final nameStart = cursor + 46, extraStart = nameStart + nameSize;
      if (nameSize == 0 ||
          nameSize > 4096 ||
          extraStart + extraSize > central.lengthInBytes) {
        throw const ArtifactFailure('archive_directory');
      }
      final expectedName = central.buffer.asUint8List(
        central.offsetInBytes + nameStart,
        nameSize,
      );
      _zipExtra(
        central.buffer.asUint8List(
          central.offsetInBytes + extraStart,
          extraSize,
        ),
      );
      final localOffset = central.getUint32(cursor + 42, Endian.little);
      if (localOffset + 30 > offset) {
        throw const ArtifactFailure('archive_directory');
      }
      await io.setPosition(localOffset);
      final local = ByteData.sublistView(await io.read(30));
      if (local.lengthInBytes != 30 ||
          local.getUint32(0, Endian.little) != 0x04034b50 ||
          local.getUint16(26, Endian.little) != nameSize ||
          local.getUint16(8, Endian.little) !=
              central.getUint16(cursor + 10, Endian.little) ||
          local.getUint16(6, Endian.little) !=
              central.getUint16(cursor + 8, Endian.little)) {
        throw const ArtifactFailure('archive_directory');
      }
      final localExtraSize = local.getUint16(28, Endian.little);
      if (localOffset +
              30 +
              nameSize +
              localExtraSize +
              central.getUint32(cursor + 20, Endian.little) >
          offset) {
        throw const ArtifactFailure('archive_directory');
      }
      final localName = await io.read(nameSize);
      if (localName.length != expectedName.length ||
          List.generate(
            localName.length,
            (i) => localName[i] == expectedName[i],
          ).contains(false)) {
        throw const ArtifactFailure('archive_directory');
      }
      _zipExtra(await io.read(localExtraSize));
      cursor +=
          46 +
          central.getUint16(cursor + 28, Endian.little) +
          central.getUint16(cursor + 30, Endian.little) +
          central.getUint16(cursor + 32, Endian.little);
    }
    if (cursor != size) throw const ArtifactFailure('archive_directory');
  } finally {
    await io.close();
  }
}

// Extraction must not interpret a second filename/link supplied by an extra
// field that differs from the complete virtual tree validated above.
void _zipExtra(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var cursor = 0;
  const safe = {
    0x5855,
    0x5455,
    0x7875,
    0x000a,
  }; // Unix/extended/NTFS timestamps and uid/gid.
  while (cursor < data.lengthInBytes) {
    if (cursor + 4 > data.lengthInBytes) {
      throw const ArtifactFailure('archive_directory');
    }
    final kind = data.getUint16(cursor, Endian.little),
        size = data.getUint16(cursor + 2, Endian.little);
    cursor += 4 + size;
    if (!safe.contains(kind) || cursor > data.lengthInBytes) {
      throw const ArtifactFailure('archive_extra');
    }
  }
}

/// Paths are derived from validated release IDs only, never from URLs or filenames.
class DesktopUpdateStore {
  DesktopUpdateStore(this.root);
  final Directory root;
  static final Set<String> _writers = {};
  RandomAccessFile? _lock;
  Future<void>? _releasing;
  Future<void> _writes = Future.value();
  Future<bool> acquireWriter() async {
    if (_releasing != null) {
      await _releasing;
      _releasing = null;
    }
    if (_lock != null) return true;
    final key = path.normalize(root.absolute.path);
    if (!_writers.add(key)) return false;
    RandomAccessFile? handle;
    try {
      await root.create(recursive: true);
      handle = await File(path.join(root.path, 'writer.lock'))
          .open(mode: FileMode.append);
      await handle.lock(FileLock.exclusive);
      _lock = handle;
      return true;
    } catch (_) {
      await handle?.close();
      _writers.remove(key);
      return false;
    }
  }

  Future<void> releaseWriter() {
    final pending = _releasing;
    if (pending != null) return pending;
    final handle = _lock;
    if (handle == null) return Future.value();
    _lock = null;
    return _releasing = () async {
      try {
        await handle.unlock();
      } finally {
        await handle.close();
        _writers.remove(path.normalize(root.absolute.path));
      }
    }();
  }

  Future<Directory> transaction(String releaseId) async {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(releaseId) ||
        releaseId == '.' ||
        releaseId == '..') {
      throw const ArtifactFailure('release_path');
    }
    await root.create(recursive: true);
    if (Platform.isMacOS) await Process.run('/bin/chmod', ['700', root.path]);
    final directory = Directory(path.join(root.path, releaseId));
    if (await FileSystemEntity.type(directory.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const ArtifactFailure('staging_link');
    }
    return directory.create(recursive: true);
  }

  Future<void> prune(String keepRelease) async {
    if (!await root.exists()) return;
    final directories = <Directory>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory || path.basename(entry.path) == keepRelease) {
        continue;
      }
      final recovery = Directory(path.join(entry.path, 'recovery'));
      if (await File(path.join(recovery.path, 'plan.json')).exists() &&
          !await File(path.join(recovery.path, 'recovery-outcome.json'))
              .exists()) {
        continue;
      }
      if (!await File(path.join(entry.path, 'update.zip')).exists() &&
          !await File(path.join(entry.path, 'update.nupkg')).exists() &&
          !await File(path.join(entry.path, 'package.partial')).exists()) {
        continue;
      }
      directories.add(entry);
    }
    final dated = await Future.wait(
      directories.map((d) async => (d, (await d.stat()).modified)),
    );
    dated.sort((a, b) => b.$2.compareTo(a.$2));
    for (final old in dated.skip(2)) {
      await old.$1.delete(recursive: true);
    }
  }

  Future<void> writeJournal(Map<String, dynamic> value) {
    final encoded = jsonEncode(value);
    final operation = _writes.catchError((Object _) {}).then((_) async {
      await root.create(recursive: true);
      final record = jsonDecode(encoded) as Map<String, dynamic>;
      final old = await readJournal();
      final previousOrder = old?['highest_order'] as int? ?? 0;
      final nextOrder = record['highest_order'] as int? ?? 0;
      if (previousOrder > nextOrder) record['highest_order'] = previousOrder;
      final temp = File(path.join(root.path, 'pending.tmp'));
      await temp.writeAsString(jsonEncode(record), flush: true);
      await temp.rename(path.join(root.path, 'pending.json'));
    });
    _writes = operation;
    return operation;
  }

  Future<Map<String, dynamic>?> readJournal() async {
    try {
      final file = File(path.join(root.path, 'pending.json'));
      if (await file.length() > 32 * 1024) return null;
      final value = jsonDecode(await file.readAsString());
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }
}
