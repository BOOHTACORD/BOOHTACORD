import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../model.dart';
import '../../../services/client_telemetry.dart';
import 'artifact.dart';
import 'download.dart';
import 'native_adapter.dart';
import 'staging.dart';

enum DesktopUpdatePhase {
  idle,
  available,
  downloading,
  verifying,
  staging,
  readyToRestart,
  applying,
  restarting,
  completed,
  failed,
  rolledBack,
}

typedef PrepareDesktopPackage = Future<void> Function(
  VerifiedInstallArtifact,
  Directory,
  DownloadCancellation,
  DownloadProgress,
);

class DesktopUpdateCoordinator extends ChangeNotifier {
  DesktopUpdateCoordinator({
    required this.trust,
    required this.local,
    required this.selector,
    required this.environment,
    required this.store,
    required this.native,
    required this.currentScope,
    required this.checkpoint,
    required this.shutdown,
    this.preparePackage,
    this.prepareRecovery,
    this.armRecovery,
    this.cancelRecovery,
  });
  final ArtifactTrust trust;
  final LocalUpdateIdentity local;
  final UpdateSelector selector;
  final UpdateEnvironment environment;
  final DesktopUpdateStore store;
  final DesktopNativeUpdater native;
  final String Function() currentScope;
  final Future<void> Function(String, VerifiedInstallArtifact) checkpoint;
  final Future<void> Function() shutdown;
  final PrepareDesktopPackage? preparePackage;
  final Future<void> Function(String, Directory)? cancelRecovery;
  String? _recoveryTransaction;
  Future<bool> Function(VerifiedInstallArtifact)? validateBeforeApply;
  final Future<void> Function(VerifiedInstallArtifact, Directory)?
  prepareRecovery;
  final Future<void> Function(String, VerifiedInstallArtifact, Directory)?
  armRecovery;
  DesktopUpdatePhase phase = DesktopUpdatePhase.idle;
  int received = 0, total = 0;
  bool bannerVisible = true;
  String? failure;
  VerifiedInstallArtifact? artifact;
  Directory? _directory;
  String? _scope;
  Future<void>? _operation;
  DownloadCancellation? _cancel;
  bool _disposed = false;
  int _epoch = 0;
  bool get working => [
    DesktopUpdatePhase.downloading,
    DesktopUpdatePhase.verifying,
    DesktopUpdatePhase.staging,
    DesktopUpdatePhase.applying,
    DesktopUpdatePhase.restarting,
  ].contains(phase);
  DesktopUpdatePhase? _lastRecorded;
  final Stopwatch _phaseClock = Stopwatch()..start();
  void _changed() {
    if (phase != _lastRecorded) {
      final wire = switch (phase) {
        DesktopUpdatePhase.downloading => 'download',
        DesktopUpdatePhase.verifying => 'verify',
        DesktopUpdatePhase.staging => 'stage',
        DesktopUpdatePhase.readyToRestart => 'ready',
        DesktopUpdatePhase.applying => 'apply',
        DesktopUpdatePhase.restarting => 'restart',
        DesktopUpdatePhase.rolledBack => 'rollback',
        _ => phase.name,
      };
      ClientTelemetry.desktopUpdate(
        wire,
        reason: failure,
        version: artifact?.version,
        durationMs: _phaseClock.elapsedMilliseconds,
      );
      _lastRecorded = phase;
      _phaseClock.reset();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> prepare(UpdateTarget target) {
    if (_operation != null) return _operation!;
    if (phase == DesktopUpdatePhase.readyToRestart) return Future.value();
    final work = _prepare(target);
    _operation = work;
    return work.whenComplete(() => _operation = null);
  }

  Future<void> _prepare(UpdateTarget target) async {
    final epoch = ++_epoch, scope = currentScope();
    _scope = scope;
    final cancellation = DownloadCancellation();
    _cancel = cancellation;
    bannerVisible = true;
    failure = null;
    received = 0;
    total = 0;
    _directory = null;
    artifact = null;
    try {
      if (!await store.acquireWriter()) {
        throw const ArtifactFailure('update_busy');
      }
      final signed = target.installArtifact;
      if (signed == null) throw const ArtifactFailure('no_install_artifact');
      final journal = await store.readJournal();
      final verified = await trust.verify(
        signed,
        local: local,
        target: target,
        selector: selector,
        environment: environment,
        highestOrder: journal?['highest_order'] as int? ?? local.releaseOrder,
      );
      _ensureCurrent(epoch, scope);
      artifact = verified;
      if (!await native.capable()) {
        throw const ArtifactFailure('installation_location');
      }
      await store.prune(verified.releaseId);
      final directory = await store.transaction(verified.releaseId);
      final free = await native.freeBytes(directory.path);
      if (free < verified.size * 2 + 5 * 1024 * 1024 * 1024) {
        throw const ArtifactFailure('disk_space');
      }
      _ensureCurrent(epoch, scope);
      artifact = verified;
      _directory = directory;
      total = verified.size;
      phase = DesktopUpdatePhase.downloading;
      _changed();
      await store.writeJournal({
        'schema_version': 1,
        'scope': scope,
        'highest_order': verified.releaseOrder,
        'phase': phase.name,
        'artifact': signed.toJson(),
      });
      void progress(int bytes, int size) {
        if (epoch == _epoch) {
          received = bytes;
          total = size;
          _changed();
        }
      }

      final prepare = preparePackage;
      if (prepare != null) {
        await prepare(verified, directory, cancellation, progress);
      } else {
        final partial = File(path.join(directory.path, 'package.partial'));
        final cached = File(
          path.join(directory.path, verified.packageFileName),
        );
        if (await cached.exists()) {
          await cached.copy(partial.path);
        } else {
          await DesktopArtifactDownloader().download(
            verified,
            partial,
            cancellation,
            progress,
          );
        }
        _ensureCurrent(epoch, scope);
        phase = DesktopUpdatePhase.verifying;
        _changed();
        await verifyAndExtract(
          partial,
          Directory(path.join(directory.path, 'payload')),
          verified,
        );
        cancellation.check();
        await partial.rename(
          path.join(directory.path, verified.packageFileName),
        );
      }
      _ensureCurrent(epoch, scope);
      cancellation.check();
      phase = DesktopUpdatePhase.staging;
      _changed();
      await native.stage(
        verified,
        path.join(directory.path, verified.packageFileName),
        path.join(directory.path, 'payload'),
      );
      await prepareRecovery?.call(verified, directory);
      _ensureCurrent(epoch, scope);
      cancellation.check();
      await store.writeJournal({
        'schema_version': 1,
        'scope': scope,
        'highest_order': verified.releaseOrder,
        'phase': 'readyToRestart',
        'artifact': signed.toJson(),
      });
      phase = DesktopUpdatePhase.readyToRestart;
      _changed();
    } catch (error) {
      if (epoch != _epoch || _disposed) return;
      if (error is ArtifactFailure &&
          [
            'digest',
            'size',
            'archive_directory',
            'archive_size',
          ].contains(error.code) &&
          _directory != null) {
        for (final name in ['package.partial', 'update.zip', 'update.nupkg']) {
          final file = File(path.join(_directory!.path, name));
          if (await file.exists()) await file.delete();
        }
      }
      phase = DesktopUpdatePhase.failed;
      failure = error is ArtifactFailure ? error.code : 'prepare';
      _changed();
    }
  }

  void _ensureCurrent(int epoch, String scope) {
    if (_disposed || epoch != _epoch || scope != currentScope()) {
      throw const ArtifactFailure('scope_changed');
    }
  }

  bool _restored = false;
  Future<void> restorePrepared(UpdateTarget? target) async {
    if (_restored ||
        target?.installArtifact == null ||
        phase != DesktopUpdatePhase.idle) {
      return;
    }
    final journal = await store.readJournal();
    if (journal?['phase'] != 'readyToRestart' ||
        journal?['scope'] != currentScope() ||
        (journal?['artifact'] as Map?)?['payload'] !=
            target!.installArtifact!.payload) {
      return;
    }
    _restored = true;
    await prepare(target);
    if (journal?['banner_hidden'] == true) {
      bannerVisible = false;
      _changed();
    }
  }

  void cancel() {
    if (![
      DesktopUpdatePhase.downloading,
      DesktopUpdatePhase.verifying,
      DesktopUpdatePhase.staging,
    ].contains(phase)) {
      return;
    }
    ++_epoch;
    _cancel?.cancel();
    phase = DesktopUpdatePhase.available;
    failure = null;
    _changed();
  }

  void scopeChanged() {
    if (_scope == null || _scope == currentScope()) return;
    ++_epoch;
    _cancel?.cancel();
    artifact = null;
    phase = DesktopUpdatePhase.idle;
    failure = null;
    bannerVisible = false;
    _changed();
  }

  void nativeFailed({String reason = 'native_apply'}) {
    final transaction = _recoveryTransaction, directory = _directory;
    if (transaction != null && directory != null) {
      unawaited(cancelRecovery?.call(transaction, directory) ?? Future.value());
    }
    phase = DesktopUpdatePhase.failed;
    failure = reason;
    bannerVisible = true;
    _changed();
  }

  void recovered({required bool rolledBack}) {
    phase = rolledBack
        ? DesktopUpdatePhase.rolledBack
        : DesktopUpdatePhase.failed;
    failure = rolledBack ? null : "manual_recovery";
    bannerVisible = true;
    _changed();
  }

  void confirmCompleted() {
    phase = DesktopUpdatePhase.completed;
    bannerVisible = true;
    _changed();
  }

  void later() {
    bannerVisible = false;
    _changed();
    if (phase == DesktopUpdatePhase.readyToRestart) {
      unawaited(
        store
            .readJournal()
            .then((journal) async {
              if (phase == DesktopUpdatePhase.readyToRestart &&
                  journal?['phase'] == 'readyToRestart' &&
                  journal?['scope'] == currentScope()) {
                await store.writeJournal({...journal!, 'banner_hidden': true});
              }
            })
            .catchError((Object _) {}),
      );
    }
  }

  Future<void> restart() async {
    if (phase != DesktopUpdatePhase.readyToRestart ||
        artifact == null ||
        _directory == null ||
        _scope != currentScope()) {
      return;
    }
    final current = artifact!,
        directory = _directory!,
        epoch = _epoch,
        scope = _scope!;
    if (current.expiresAt.isBefore(DateTime.now().toUtc())) {
      phase = DesktopUpdatePhase.failed;
      failure = 'expired';
      _changed();
      return;
    }
    phase = DesktopUpdatePhase.applying;
    failure = null;
    _changed();
    try {
      if (await validateBeforeApply?.call(current) == false) {
        throw const ArtifactFailure('compatibility_changed');
      }
      _ensureCurrent(epoch, scope);
      await verifyPackageDigest(
        File(path.join(directory.path, current.packageFileName)),
        current,
      );
      final transaction = const Uuid().v4();
      await checkpoint(
        transaction,
        current,
      ).timeout(const Duration(seconds: 15));
      _ensureCurrent(epoch, scope);
      await shutdown().timeout(const Duration(seconds: 15));
      _ensureCurrent(epoch, scope);
      await store.writeJournal({
        'schema_version': 1,
        'scope': scope,
        'highest_order': current.releaseOrder,
        'phase': 'applying',
        'transaction': transaction,
        'artifact': current.envelope.toJson(),
      });
      _recoveryTransaction = transaction;
      await armRecovery?.call(transaction, current, directory);
      // No helper is created by download, Later, focus or lifecycle timers.
      await native.apply(
        current,
        path.join(directory.path, current.packageFileName),
        path.join(directory.path, 'payload'),
      );
      phase = DesktopUpdatePhase.restarting;
      _changed();
    } catch (error) {
      final transaction = _recoveryTransaction;
      if (transaction != null) {
        await cancelRecovery?.call(transaction, directory);
      }
      phase = DesktopUpdatePhase.failed;
      failure = error is ArtifactFailure ? error.code : 'apply';
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _cancel?.cancel();
    unawaited(store.releaseWriter());
    super.dispose();
  }
}
