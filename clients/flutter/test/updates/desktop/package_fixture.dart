import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/artifact.dart';

Future<VerifiedInstallArtifact> testPackage(
  List<int> bytes, {
  bool macos = false,
}) async {
  final key = await Ed25519().newKeyPairFromSeed(
    List<int>.generate(32, (i) => i + 1),
  );
  final raw = utf8.encode(
    jsonEncode({
      'schema_version': 1,
      'application_family': 'boohtacord',
      'package_id': macos
          ? 'ru.boohtacord.boohtacordDesktop'
          : 'boohtacord_desktop',
      'release_id': 'test-2',
      'release_order': 2,
      'version': '1.0.2',
      'native_build': '2',
      'platform': macos ? 'macos' : 'windows',
      'arch': macos ? 'any' : 'x64',
      'distribution': 'direct',
      'channel': 'stable',
      'package_type': macos ? 'sparkle_zip' : 'velopack_nupkg',
      'download_url': 'https://github.com/BOOHTACORD/BOOHTACORD/releases/download/test-v1.0.2/package.zip',
      'size': bytes.length,
      'sha256': crypto.sha256.convert(bytes).toString(),
      'min_os_version': macos ? '13.0' : '10.0',
      'min_api_version': 1,
      'min_updater_version': 1,
      'expires_at': '2028-10-14T00:00:00Z',
      if (macos) 'native_signature': base64Encode(List<int>.filled(64, 1)),
    }),
  );
  final signature = await Ed25519().sign([
    ...utf8.encode(artifactDomain),
    ...raw,
  ], keyPair: key);
  return ArtifactTrust({'fixture': (await key.extractPublicKey()).bytes})
      .verify(
        SignedInstallArtifact(
          keyId: 'fixture',
          payload: base64Encode(raw),
          signature: base64Encode(signature.bytes),
        ),
        local: LocalUpdateIdentity(
          releaseId: 'test-1',
          releaseOrder: 1,
          packageName: macos
              ? 'ru.boohtacord.boohtacordDesktop'
              : 'boohtacord_desktop',
        ),
        target: const UpdateTarget(
          releaseId: 'test-2',
          releaseOrder: 2,
          version: '1.0.2',
          nativeBuild: '2',
          arches: ['any'],
        ),
        selector: UpdateSelector(
          macos ? 'macos' : 'windows',
          'direct',
          'stable',
          macos ? 'arm64' : 'x64',
        ),
        environment: UpdateEnvironment(
          osVersion: macos ? '13.0' : '10.0',
          arch: macos ? 'arm64' : 'x64',
        ),
        highestOrder: 1,
      );
}
