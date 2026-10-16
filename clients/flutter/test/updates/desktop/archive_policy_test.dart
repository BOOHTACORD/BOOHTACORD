import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/archive_policy.dart';

void main() {
  test('rejects traversal, Windows drive, UNC and backslash paths before extraction', () {
    for (final name in [
      '../escape',
      '/tmp/escape',
      'C:/escape',
      'a/../../escape',
      'a\\..\\escape',
      '//host/share',
    ]) {
      final a = Archive()..addFile(ArchiveFile.bytes(name, [1]));
      expect(
        () => validateUpdateArchive(a, macos: false),
        throwsFormatException,
        reason: name,
      );
    }
  });
  test('permits Mac framework internal links but rejects external and cyclic links', () {
    final a = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'BOOHTACORD.app/Contents/Frameworks/X.framework/Versions/A/X',
          [1],
        ),
      )
      ..addFile(
        ArchiveFile.symlink(
          'BOOHTACORD.app/Contents/Frameworks/X.framework/Versions/Current',
          'A',
        ),
      )
      ..addFile(
        ArchiveFile.symlink(
          'BOOHTACORD.app/Contents/Frameworks/X.framework/X',
          'Versions/Current/X',
        ),
      );
    expect(() => validateUpdateArchive(a, macos: true), returnsNormally);
    a.addFile(ArchiveFile.symlink('BOOHTACORD.app/evil', '../../outside'));
    expect(() => validateUpdateArchive(a, macos: true), throwsFormatException);
    final cycle = Archive()
      ..addFile(ArchiveFile.symlink('a', 'b'))
      ..addFile(ArchiveFile.symlink('b', 'a'));
    expect(
      () => validateUpdateArchive(cycle, macos: true),
      throwsFormatException,
    );
  });
  test('rejects zip bombs, duplicate paths and Windows reparse-like links', () {
    final bomb = Archive()
      ..addFile(ArchiveFile.noData('huge')..size = 3 * 1024 * 1024 * 1024);
    expect(
      () => validateUpdateArchive(bomb, macos: false),
      throwsFormatException,
    );
    final link = Archive()..addFile(ArchiveFile.symlink('x', 'y'));
    expect(
      () => validateUpdateArchive(link, macos: false),
      throwsFormatException,
    );
    final aliases = Archive()
      ..addFile(ArchiveFile.bytes('Dir/File', [1]))
      ..addFile(ArchiveFile.bytes('dir/file', [2]));
    expect(
      () => validateUpdateArchive(aliases, macos: false),
      throwsFormatException,
    );
  });
}
