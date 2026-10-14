import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/artifact.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/coordinator.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/native_adapter.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/staging.dart';

class Native implements DesktopNativeUpdater {
  int staged = 0, applied = 0;
  bool support = true;
  @override
  Future<bool> capable() async => support;
  @override
  Future<int> freeBytes(String directory) async => 10 * 1024 * 1024 * 1024;
  @override
  Future<void> stage(
    VerifiedInstallArtifact a,
    String archive,
    String extracted,
  ) async {
    staged++;
  }

  @override
  Future<void> apply(
    VerifiedInstallArtifact a,
    String archive,
    String extracted,
  ) async {
    applied++;
  }

  @override
  Future<void> acknowledge(String id, String version, String build) async {}
}

void main() {
  late Directory root;
  late Native native;
  late DesktopUpdateCoordinator coordinator;
  var scope = 'account-1', checkpointCount = 0, shutdownCount = 0;
  late UpdateTarget target;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('update-coordinator-test-');
    native = Native();
    final key = await Ed25519().newKeyPair();
    final public = (await key.extractPublicKey()).bytes;
    final payload = utf8.encode(
      jsonEncode({
        'schema_version': 1,
        'application_family': 'boohtacord',
        'package_id': 'boohtacord_desktop',
        'release_id': 'win-2',
        'release_order': 2,
        'version': '1.0.2',
        'native_build': '2',
        'platform': 'windows',
        'arch': 'x64',
        'distribution': 'direct',
        'channel': 'stable',
        'package_type': 'velopack_nupkg',
        'download_url': 'https://github.com/Egkurilov/BOOHTACORD/releases/download/windows-v1.0.2/app.nupkg',
        'size': 10,
        'sha256': crypto.sha256.convert(List<int>.filled(10, 7)).toString(),
        'min_os_version': '10.0',
        'min_api_version': 1,
        'min_updater_version': 1,
        'expires_at': '2027-10-14T00:00:00Z',
      }),
    );
    final signature = await Ed25519().sign([
      ...utf8.encode(artifactDomain),
      ...payload,
    ], keyPair: key);
    target = UpdateTarget(
      releaseId: 'win-2',
      releaseOrder: 2,
      version: '1.0.2',
      nativeBuild: '2',
      arches: ['x64'],
      installArtifact: SignedInstallArtifact(
        keyId: 'test',
        payload: base64Encode(payload),
        signature: base64Encode(signature.bytes),
      ),
    );
    scope = 'account-1';
    checkpointCount = 0;
    shutdownCount = 0;
    coordinator = DesktopUpdateCoordinator(
      trust: ArtifactTrust({'test': public}),
      local: const LocalUpdateIdentity(
        releaseId: 'win-1',
        releaseOrder: 1,
        packageName: 'boohtacord_desktop',
      ),
      selector: const UpdateSelector.windows('x64'),
      environment: const UpdateEnvironment(osVersion: '10.0.1', arch: 'x64'),
      store: DesktopUpdateStore(root),
      native: native,
      currentScope: () => scope,
      preparePackage: (a, dir, cancel, progress) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await File('${dir.path}/${a.packageFileName}')
            .writeAsBytes(List<int>.filled(10, 7));
        progress(a.size, a.size);
      },
      checkpoint: (transaction, artifact) async {
        checkpointCount++;
      },
      shutdown: () async {
        shutdownCount++;
      },
    );
  });
  tearDown(() async {
    coordinator.dispose();
    await root.delete(recursive: true);
  });
  test(
    'repeated Update clicks prepare once; Later never launches native apply',
    () async {
      await Future.wait([
        coordinator.prepare(target),
        coordinator.prepare(target),
      ]);
      expect(coordinator.phase, DesktopUpdatePhase.readyToRestart);
      expect(native.staged, 1);
      coordinator.later();
      expect(native.applied, 0);
      expect(checkpointCount, 0);
      await coordinator.restart();
      expect(native.applied, 1);
      expect(checkpointCount, 1);
      expect(shutdownCount, 1);
    },
  );
  test(
    'account changes invalidate in-flight target and no helper runs',
    () async {
      final work = coordinator.prepare(target);
      scope = 'account-2';
      coordinator.scopeChanged();
      await work;
      expect(native.applied, 0);
      expect(coordinator.phase, isNot(DesktopUpdatePhase.readyToRestart));
      await coordinator.restart();
      expect(checkpointCount, 0);
    },
  );
  test('changed compatibility policy prevents checkpoint and helper', () async {
    await coordinator.prepare(target);
    coordinator.validateBeforeApply = (_) async => false;
    await coordinator.restart();
    expect(coordinator.phase, DesktopUpdatePhase.failed);
    expect(checkpointCount, 0);
    expect(native.applied, 0);
  });
  test('tampering after Ready is rejected before shutdown', () async {
    await coordinator.prepare(target);
    await File('${root.path}/win-2/update.nupkg')
        .writeAsBytes(List<int>.filled(10, 8));
    await coordinator.restart();
    expect(coordinator.failure, 'digest');
    expect(checkpointCount, 0);
    expect(shutdownCount, 0);
  });
  test(
    'unsupported portable installation fails before downloading or applying',
    () async {
      native.support = false;
      await coordinator.prepare(target);
      expect(coordinator.phase, DesktopUpdatePhase.failed);
      expect(native.staged, 0);
      expect(native.applied, 0);
    },
  );
}
