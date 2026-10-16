import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

/// Validates the complete virtual filesystem before any entry is written.
/// Mac framework symlinks may point inside the archive, never outside staging.
void validateUpdateArchive(Archive archive, {required bool macos}) {
  if (archive.isEmpty || archive.length > 50000) {
    throw const FormatException('archive_count');
  }
  var total = 0;
  final entries = <String, ArchiveFile>{};
  String clean(String raw) {
    if (raw.isEmpty ||
        raw.length > 1024 ||
        raw.contains('\\') ||
        raw.contains('\u0000') ||
        raw.startsWith('/') ||
        raw.contains(':')) {
      throw const FormatException('archive_path');
    }
    final n = path.posix.normalize(raw);
    if (n == '.' ||
        n == '..' ||
        n.startsWith('../') ||
        raw.split('/').contains('..')) {
      throw const FormatException('archive_path');
    }
    return n;
  }

  final caseNames = <String>{};
  for (final e in archive) {
    final n = clean(e.name);
    if (entries.containsKey(n) || !caseNames.add(n.toLowerCase())) {
      throw const FormatException('archive_alias');
    }
    entries[n] = e;
    total += e.size;
    if (e.size < 0 ||
        e.size > 1024 * 1024 * 1024 ||
        total > 2 * 1024 * 1024 * 1024) {
      throw const FormatException('archive_size');
    }
    if (e.isSymbolicLink && !macos) throw const FormatException('archive_link');
    if (!macos &&
        n
            .split('/')
            .any(
              (part) =>
                  RegExp(
                    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
                    caseSensitive: false,
                  ).hasMatch(part) ||
                  part.endsWith('.') ||
                  part.endsWith(' '),
            )) {
      throw const FormatException('archive_windows_path');
    }
  }
  String resolve(String raw, Set<String> visited) {
    final n = path.posix.normalize(raw);
    if (n == '..' || n.startsWith('../') || path.posix.isAbsolute(n)) {
      throw const FormatException('archive_link_escape');
    }
    final parts = n.split('/');
    for (var i = 1; i <= parts.length; i++) {
      final prefix = parts.take(i).join('/'), entry = entries[prefix];
      if (entry?.isSymbolicLink == true) {
        if (visited.length > 40 || !visited.add(prefix)) {
          throw const FormatException('archive_link_cycle');
        }
        final link = entry!.symbolicLink!;
        if (link.contains('\\') ||
            link.contains(':') ||
            link.contains('\u0000') ||
            path.posix.isAbsolute(link)) {
          throw const FormatException('archive_link_escape');
        }
        return resolve(
          path.posix.joinAll([
            path.posix.dirname(prefix),
            link,
            ...parts.skip(i),
          ]),
          visited,
        );
      }
      if (i < parts.length &&
          entry != null &&
          entry.isFile &&
          !entry.isSymbolicLink) {
        throw const FormatException('archive_parent_file');
      }
    }
    return n;
  }

  for (final name in entries.keys) {
    resolve(name, <String>{});
  }
}
