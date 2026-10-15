import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'baseline.dart';

import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

import '../model.dart';
import 'artifact.dart';

/// Local baseline only. No server field can choose a helper, path or command.
class DesktopRecovery {
  DesktopRecovery(this.local);
  final LocalUpdateIdentity local;
  Directory _root(Directory transaction) =>
      Directory(path.join(transaction.path, 'recovery'));

  Future<void> stage(
    VerifiedInstallArtifact artifact,
    Directory transaction,
  ) async {
    final root = _root(transaction);
    if (await root.exists()) {
      final plan = File(path.join(root.path, 'plan.json'));
      final outcome = File(path.join(root.path, 'recovery-outcome.json'));
      if (await plan.exists() && !await outcome.exists()) {
        throw const ArtifactFailure('recovery_busy');
      }
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);
    if (Platform.isMacOS) {
      final bundle = File(Platform.resolvedExecutable).parent.parent.parent;
      final helper = Directory(
        path.join(
          bundle.path,
          'Contents',
          'Resources',
          'BOOHTACORDRecovery.app',
        ),
      );
      if (!await helper.exists()) {
        throw const ArtifactFailure('recovery_missing');
      }
      // The bundled native monitor retains these after explicit apply consent.
      // Executables written here by the sandbox cannot be launched on macOS.
    } else {
      // Preserve the whole known-running version, never a server-selected file.
      final current = File(Platform.resolvedExecutable).parent;
      final source = current.path, destination = root.path;
      await Isolate.run(
        () => retainWindowsBaseline(Directory(source), Directory(destination)),
      );
      await File(path.join(current.path, 'BOOHTACORDRecovery.exe'))
          .copy(path.join(root.path, 'BOOHTACORDRecovery.exe'));
    }
  }

  Future<void> arm(
    String transactionId,
    VerifiedInstallArtifact artifact,
    Directory transaction,
  ) async {
    final root = _root(transaction);
    final target = Platform.isMacOS
        ? File(Platform.resolvedExecutable).parent.parent.parent.path
        : File(Platform.resolvedExecutable).parent.path;
    for (final name in [
      'cancel.json',
      'recovery-ready.json',
      'bootstrap-ack.json',
      'recovery-outcome.json',
    ]) {
      final old = File(path.join(root.path, name));
      if (await old.exists()) await old.delete();
    }
    final plan = File(path.join(root.path, 'plan.json'));
    await plan.writeAsString(
      jsonEncode({
        'schema_version': 1,
        'transaction': transactionId,
        'target': target,
        'backup': path.join(
          root.path,
          Platform.isMacOS ? 'previous.app' : 'previous',
        ),
        'old_pid': pid,
        'old_build': local.nativeBuild,
        'new_build': artifact.nativeBuild,
        'new_release': artifact.releaseId,
      }),
      flush: true,
    );
    if (Platform.isMacOS) {
      await const MethodChannel('boohtacord/desktop_updates')
          .invokeMethod<void>('armRecovery', {'plan': plan.path});
    } else {
      await Process.start(path.join(root.path, 'BOOHTACORDRecovery.exe'), [
        '--plan',
        plan.path,
      ], mode: ProcessStartMode.detached);
    }
    final ready = File(path.join(root.path, 'recovery-ready.json'));
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await ready.length() < 4096 &&
            (jsonDecode(await ready.readAsString()) as Map)['transaction'] ==
                transactionId) {
          return;
        }
      } catch (_) {}
      final result = await outcome(transaction, transactionId);
      if (result?['status'] == 'manualRecovery') {
        if (['replace_denied', 'recovery_volume'].contains(result?['reason'])) {
          throw const ArtifactFailure('installation_location');
        }
        throw const ArtifactFailure('recovery_identity');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw const ArtifactFailure('recovery_start');
  }

  Future<void> cancel(String id, Directory transaction) async {
    final root = _root(transaction);
    if (!await root.exists()) return;
    await File(path.join(root.path, 'cancel.json'))
        .writeAsString(jsonEncode({'transaction': id}), flush: true);
    final outcome = File(path.join(root.path, 'recovery-outcome.json'));
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await outcome.length() < 4096 &&
            (jsonDecode(await outcome.readAsString()) as Map)['transaction'] ==
                id) {
          return;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> acknowledge(
    String id,
    VerifiedInstallArtifact artifact,
    Directory transaction,
  ) async {
    final root = _root(transaction);
    final temporary = File(path.join(root.path, 'bootstrap-ack.tmp'));
    await temporary.writeAsString(
      jsonEncode({
        'transaction': id,
        'release_id': artifact.releaseId,
        'native_build': artifact.nativeBuild,
      }),
      flush: true,
    );
    await temporary.rename(path.join(root.path, 'bootstrap-ack.json'));
  }

  Future<Map<String, dynamic>?> outcome(
    Directory transaction,
    String id,
  ) async {
    try {
      final file = File(
        path.join(_root(transaction).path, 'recovery-outcome.json'),
      );
      if (await file.length() > 4096) return null;
      final value = jsonDecode(await file.readAsString());
      if (value is Map<String, dynamic> &&
          value['transaction'] == id &&
          [
            'rolledBack',
            'manualRecovery',
            'completed',
          ].contains(value['status'])) {
        return value;
      }
    } catch (_) {}
    return null;
  }
}
