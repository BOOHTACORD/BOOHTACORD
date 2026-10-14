import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/artifact.dart';

void main() {
  final algorithm = Ed25519();
  late SimpleKeyPair key;
  late ArtifactTrust trust;
  late Map<String, dynamic> payload;
  const selector = UpdateSelector.windows('x64');
  const local = LocalUpdateIdentity(
    releaseId: 'win-1',
    releaseOrder: 1,
    platform: 'windows',
    packageName: 'boohtacord_desktop',
  );
  const target = UpdateTarget(
    releaseId: 'win-2',
    releaseOrder: 2,
    version: '1.0.2',
    nativeBuild: '2',
    arches: ['x64'],
  );
  Future<SignedInstallArtifact> signed({String id = 'test'}) async {
    final bytes = utf8.encode(jsonEncode(payload));
    final signature = await algorithm.sign([
      ...utf8.encode(artifactDomain),
      ...bytes,
    ], keyPair: key);
    return SignedInstallArtifact(
      keyId: id,
      payload: base64Encode(bytes),
      signature: base64Encode(signature.bytes),
    );
  }

  Future<VerifiedInstallArtifact> verify(SignedInstallArtifact envelope) =>
      trust.verify(
        envelope,
        local: local,
        target: target,
        selector: selector,
        environment: const UpdateEnvironment(
          osVersion: '10.0.19045',
          arch: 'x64',
        ),
        highestOrder: 1,
      );
  setUp(() async {
    key = await algorithm.newKeyPairFromSeed(List.generate(32, (i) => i));
    trust = ArtifactTrust({'test': (await key.extractPublicKey()).bytes});
    payload = {
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
      'download_url': 'https://github.com/Egkurilov/BOOHTACORD/releases/download/windows-v1.0.2/boohtacord-1.0.2-full.nupkg',
      'size': 1024,
      'sha256': 'a' * 64,
      'min_os_version': '10.0.0',
      'min_api_version': 1,
      'min_updater_version': 1,
      'expires_at': '2027-10-14T00:00:00Z',
    };
  });
  test(
    'publisher signature authorizes exactly the selected identity and target',
    () async {
      final artifact = await verify(await signed());
      expect(artifact.releaseId, 'win-2');
      expect(artifact.size, 1024);
    },
  );
  test(
    'unknown server supplied key and tampered signed bytes fail closed',
    () async {
      await expectLater(
        verify(await signed(id: 'server-key')),
        throwsA(isA<ArtifactFailure>()),
      );
      final valid = await signed();
      payload['size'] = 2048;
      await expectLater(
        verify(
          SignedInstallArtifact(
            keyId: valid.keyId,
            payload: base64Encode(utf8.encode(jsonEncode(payload))),
            signature: valid.signature,
          ),
        ),
        throwsA(isA<ArtifactFailure>()),
      );
    },
  );
  test(
    'authentic but retargeted, downgraded or mismatched package fails',
    () async {
      for (final entry in {
        'release_id': 'other',
        'release_order': 1,
        'platform': 'macos',
        'arch': 'arm64',
        'package_id': 'other',
        'version': '1.0.3',
        'native_build': '3',
        'min_updater_version': 2,
        'size': -1,
        'expires_at': '2020-01-01T00:00:00Z',
      }.entries) {
        final previous = payload[entry.key];
        payload[entry.key] = entry.value;
        await expectLater(
          verify(await signed()),
          throwsA(isA<ArtifactFailure>()),
          reason: entry.key,
        );
        payload[entry.key] = previous;
      }
    },
  );
  test('arbitrary origins, credentials and path confusion are never installer sources', () async {
    for (final url in [
      'https://evil.test/app.nupkg',
      'https://github.com.evil.test/Egkurilov/BOOHTACORD/releases/download/a/b',
      'https://user:secret@github.com/Egkurilov/BOOHTACORD/releases/download/a/b',
      'http://github.com/Egkurilov/BOOHTACORD/releases/download/a/b',
      'https://github.com/Egkurilov/BOOHTACORD/releases/download/a/../b',
    ]) {
      payload['download_url'] = url;
      await expectLater(
        verify(await signed()),
        throwsA(isA<ArtifactFailure>()),
      );
    }
  });
}
