import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;

import '../../../app_version.dart';
import 'artifact.dart';
import 'native_adapter.dart';
import 'windows_identity.dart';

String velopackFeedFileName(String channel) {
  if (!const {'stable', 'beta', 'development'}.contains(channel)) {
    throw const ArtifactFailure('native_channel');
  }
  return 'releases.$channel.json';
}

final class _Options extends Struct {
  @Bool()
  external bool allowDowngrade;
  external Pointer<Utf8> channel;
  @Int32()
  external int maximumDeltas;
}

final class _Asset extends Struct {
  external Pointer<Utf8> packageId;
  external Pointer<Utf8> version;
  external Pointer<Utf8> type;
  external Pointer<Utf8> fileName;
  external Pointer<Utf8> sha1;
  external Pointer<Utf8> sha256;
  @Uint64()
  external int size;
  external Pointer<Utf8> notesMarkdown;
  external Pointer<Utf8> notesHtml;
}

final class _Info extends Struct {
  external Pointer<_Asset> target;
  external Pointer<_Asset> base;
  external Pointer<Pointer<_Asset>> deltas;
  @Size()
  external int deltasCount;
  @Bool()
  external bool downgrade;
}

class VelopackDesktopUpdater implements DesktopNativeUpdater {
  VelopackDesktopUpdater(this.root);
  final Directory root;
  static DynamicLibrary _library() => DynamicLibrary.open(
    path.join(
      File(Platform.resolvedExecutable).parent.path,
      'velopack_libc.dll',
    ),
  );
  static Pointer<Void> _manager(
    DynamicLibrary library,
    String source, {
    String channelName = appChannel,
  }) {
    velopackFeedFileName(channelName);
    final create = library
        .lookupFunction<
          Bool Function(
            Pointer<Utf8>,
            Pointer<_Options>,
            Pointer<Void>,
            Pointer<Pointer<Void>>,
          ),
          bool Function(
            Pointer<Utf8>,
            Pointer<_Options>,
            Pointer<Void>,
            Pointer<Pointer<Void>>,
          )
        >('vpkc_new_update_manager');
    final options = calloc<_Options>(),
        output = calloc<Pointer<Void>>(),
        url = source.toNativeUtf8(),
        channel = channelName.toNativeUtf8();
    try {
      options.ref.allowDowngrade = false;
      options.ref.channel = channel;
      options.ref.maximumDeltas = -1;
      if (!create(url, options, nullptr, output) || output.value == nullptr) {
        throw const ArtifactFailure('installation_location');
      }
      return output.value;
    } finally {
      calloc.free(options);
      calloc.free(output);
      calloc.free(url);
      calloc.free(channel);
    }
  }

  static void _free(DynamicLibrary library, Pointer<Void> manager) =>
      library.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('vpkc_free_update_manager')(manager);
  @override
  Future<bool> capable() async {
    final current = File(Platform.resolvedExecutable).parent;
    final perUser = Platform.environment['LOCALAPPDATA'];
    if (perUser == null ||
        path.basename(current.path).toLowerCase() != 'current' ||
        !path.isWithin(perUser.toLowerCase(), current.path.toLowerCase()) ||
        !await File(path.join(current.parent.path, 'Update.exe')).exists()) {
      return false;
    }
    try {
      final library = _library(), manager = _manager(_library(), root.path);
      try {
        final buffer = calloc<Uint8>(256);
        try {
          final count = library
              .lookupFunction<
                Size Function(Pointer<Void>, Pointer<Utf8>, Size),
                int Function(Pointer<Void>, Pointer<Utf8>, int)
              >('vpkc_get_app_id')(manager, buffer.cast(), 256);
          return count > 0 &&
              count < 256 &&
              buffer.cast<Utf8>().toDartString() == 'boohtacord_desktop';
        } finally {
          calloc.free(buffer);
        }
      } finally {
        _free(library, manager);
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> freeBytes(String directory) async {
    final get = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<
          Int32 Function(
            Pointer<Utf16>,
            Pointer<Uint64>,
            Pointer<Uint64>,
            Pointer<Uint64>,
          ),
          int Function(
            Pointer<Utf16>,
            Pointer<Uint64>,
            Pointer<Uint64>,
            Pointer<Uint64>,
          )
        >('GetDiskFreeSpaceExW');
    final name = directory.toNativeUtf16(), free = calloc<Uint64>();
    try {
      return get(name, free, nullptr, nullptr) != 0 ? free.value : 0;
    } finally {
      calloc.free(name);
      calloc.free(free);
    }
  }

  static Future<void> _selected(
    VerifiedInstallArtifact artifact,
    String archive, {
    required bool apply,
  }) async {
    final source = Directory(
      path.join(File(archive).parent.path, 'native-feed'),
    );
    await source.create(recursive: true);
    final filename = artifact.downloadUrl.pathSegments.last;
    await File(archive).copy(path.join(source.path, filename));
    final channel = artifact.values['channel'] as String;
    await File(path.join(source.path, velopackFeedFileName(channel)))
        .writeAsString(
          jsonEncode({
            'Assets': [
              {
                'PackageId': artifact.packageId,
                'Version': artifact.version,
                'Type': 'Full',
                'FileName': filename,
                'SHA1': '',
                'SHA256': artifact.sha256,
                'Size': artifact.size,
                'NotesMarkdown': '',
                'NotesHtml': '',
              },
            ],
          }),
          flush: true,
        );
    final library = _library(),
        manager = _manager(_library(), source.path, channelName: channel),
        info = calloc<Pointer<_Info>>();
    try {
      final check = library
          .lookupFunction<
            Int8 Function(Pointer<Void>, Pointer<Pointer<_Info>>),
            int Function(Pointer<Void>, Pointer<Pointer<_Info>>)
          >('vpkc_check_for_updates');
      check(manager, info);
      if (info.value == nullptr || info.value.ref.target == nullptr) {
        throw const ArtifactFailure('native_target');
      }
      final target = info.value.ref.target;
      if (target.ref.packageId.toDartString() != artifact.packageId ||
          target.ref.version.toDartString() != artifact.version ||
          target.ref.sha256.toDartString().toLowerCase() != artifact.sha256 ||
          target.ref.size != artifact.size ||
          target.ref.fileName.toDartString() != filename) {
        throw const ArtifactFailure('native_target');
      }
      if (!apply) {
        final download = library
            .lookupFunction<
              Bool Function(
                Pointer<Void>,
                Pointer<_Info>,
                Pointer<Void>,
                Pointer<Void>,
              ),
              bool Function(
                Pointer<Void>,
                Pointer<_Info>,
                Pointer<Void>,
                Pointer<Void>,
              )
            >('vpkc_download_updates');
        if (!download(manager, info.value, nullptr, nullptr)) {
          throw const ArtifactFailure('native_stage');
        }
      } else {
        final cached = File(
          path.join(
            File(Platform.resolvedExecutable).parent.parent.path,
            'packages',
            filename,
          ),
        );
        if (!await cached.exists() ||
            await cached.length() != artifact.size ||
            (await crypto.sha256.bind(cached.openRead()).first).toString() !=
                artifact.sha256) {
          throw const ArtifactFailure('digest');
        }
        final install = library
            .lookupFunction<
              Bool Function(
                Pointer<Void>,
                Pointer<_Asset>,
                Bool,
                Bool,
                Pointer<Pointer<Utf8>>,
                Size,
              ),
              bool Function(
                Pointer<Void>,
                Pointer<_Asset>,
                bool,
                bool,
                Pointer<Pointer<Utf8>>,
                int,
              )
            >('vpkc_wait_exit_then_apply_updates');
        if (!install(manager, target, true, true, nullptr, 0)) {
          throw const ArtifactFailure('native_apply');
        }
      }
    } finally {
      if (info.value != nullptr) {
        library.lookupFunction<
          Void Function(Pointer<_Info>),
          void Function(Pointer<_Info>)
        >('vpkc_free_update_info')(info.value);
      }
      calloc.free(info);
      _free(library, manager);
    }
  }

  @override
  Future<void> stage(
    VerifiedInstallArtifact a,
    String archive,
    String extracted,
  ) => Isolate.run(() async {
    await verifyWindowsPackage(extracted, a);
    await _selected(a, archive, apply: false);
  });
  @override
  Future<void> apply(
    VerifiedInstallArtifact a,
    String archive,
    String extracted,
  ) async {
    await Isolate.run(() => _selected(a, archive, apply: true));
    exit(0); // Checkpoint and graceful shutdown have already completed.
  }

  @override
  Future<void> acknowledge(
    String id,
    String version,
    String nativeBuild,
  ) async {}
}
