import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../model.dart';
import '../package_identity/build_number.dart';

const artifactDomain = 'BOOHTACORD-DESKTOP-ARTIFACT-v1\n';
const maximumArtifactBytes = 1024 * 1024 * 1024;

class ArtifactFailure implements Exception {
  const ArtifactFailure(this.code);
  final String code;
  @override
  String toString() => 'Desktop update rejected ($code)';
}

class SignedInstallArtifact {
  const SignedInstallArtifact({
    required this.keyId,
    required this.payload,
    required this.signature,
  });
  factory SignedInstallArtifact.fromJson(Map<String, dynamic> value) {
    if (value.length != 4 ||
        value['schema_version'] != 1 ||
        value['key_id'] is! String ||
        value['payload'] is! String ||
        value['signature'] is! String ||
        (value['payload'] as String).length > 16384 ||
        (value['signature'] as String).length != 88 ||
        !RegExp(r'^[a-zA-Z0-9._-]{1,96}$')
            .hasMatch(value['key_id'] as String)) {
      throw const ArtifactFailure('envelope');
    }
    return SignedInstallArtifact(
      keyId: value['key_id'] as String,
      payload: value['payload'] as String,
      signature: value['signature'] as String,
    );
  }
  final String keyId, payload, signature;
  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'key_id': keyId,
    'payload': payload,
    'signature': signature,
  };
}

/// Instances can only be constructed after authenticating a publisher envelope.
class VerifiedInstallArtifact {
  VerifiedInstallArtifact._(this.envelope, this.values);
  final SignedInstallArtifact envelope;
  final Map<String, dynamic> values;
  String get releaseId => values['release_id'] as String;
  int get releaseOrder => values['release_order'] as int;
  String get version => values['version'] as String;
  String get nativeBuild => values['native_build'] as String;
  String get packageId => values['package_id'] as String;
  String get packageType => values['package_type'] as String;
  String get sha256 => values['sha256'] as String;
  int get size => values['size'] as int;
  String get packageFileName =>
      packageType == 'sparkle_zip' ? 'update.zip' : 'update.nupkg';
  Uri get downloadUrl => Uri.parse(values['download_url'] as String);
  DateTime get expiresAt => DateTime.parse(values['expires_at'] as String);
  String? get nativeSignature => values['native_signature'] as String?;
}

class ArtifactTrust {
  ArtifactTrust(Map<String, List<int>> roots)
    : _roots = Map.unmodifiable(
        roots.map((k, v) => MapEntry(k, List<int>.unmodifiable(v))),
      );
  final Map<String, List<int>> _roots;
  Future<VerifiedInstallArtifact> verify(
    SignedInstallArtifact envelope, {
    required LocalUpdateIdentity local,
    required UpdateTarget target,
    required UpdateSelector selector,
    required UpdateEnvironment environment,
    required int highestOrder,
    bool confirmingInstalled = false,
  }) async {
    try {
      final root = _roots[envelope.keyId];
      if (root == null ||
          root.length != 32 ||
          envelope.payload.length > 16384) {
        throw const ArtifactFailure('publisher');
      }
      final bytes = base64Decode(envelope.payload),
          signature = base64Decode(envelope.signature);
      if (bytes.length > 12288 ||
          signature.length != 64 ||
          !await Ed25519().verify(
            [...utf8.encode(artifactDomain), ...bytes],
            signature: Signature(
              signature,
              publicKey: SimplePublicKey(root, type: KeyPairType.ed25519),
            ),
          )) {
        throw const ArtifactFailure('signature');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const ArtifactFailure('payload');
      }
      final v = decoded;
      const required = {
        'schema_version',
        'application_family',
        'package_id',
        'release_id',
        'release_order',
        'version',
        'native_build',
        'platform',
        'arch',
        'distribution',
        'channel',
        'package_type',
        'download_url',
        'size',
        'sha256',
        'min_os_version',
        'min_api_version',
        'min_updater_version',
        'expires_at',
      };
      if (!required.every(v.containsKey) ||
          v.keys.any((k) => !required.contains(k) && k != 'native_signature') ||
          v['schema_version'] != 1 ||
          v['application_family'] != 'boohtacord' ||
          v['package_id'] != local.packageName ||
          (local.expectedPackageName != null &&
              local.packageName != local.expectedPackageName) ||
          (local.version != null && local.installedVersion != local.version) ||
          !packageBuildMatches(
            platform: selector.platform,
            arch: selector.arch,
            declared: local.nativeBuild,
            installed: local.installedBuild,
          ) ||
          v['release_id'] != target.releaseId ||
          v['release_order'] != target.releaseOrder ||
          v['version'] != target.version ||
          v['native_build'] != target.nativeBuild ||
          v['platform'] != selector.platform ||
          (selector.platform == 'windows' && v['arch'] != 'x64') ||
          v['distribution'] != selector.distribution ||
          v['channel'] != selector.channel ||
          !(v['arch'] == selector.arch || v['arch'] == 'any') ||
          !['windows', 'macos'].contains(selector.platform) ||
          selector.distribution != 'direct' ||
          v['release_order'] is! int ||
          (confirmingInstalled
              ? (target.releaseId != local.releaseId ||
                    target.releaseOrder != local.releaseOrder ||
                    target.version != local.installedVersion ||
                    !packageBuildMatches(
                      platform: selector.platform,
                      arch: selector.arch,
                      declared: target.nativeBuild,
                      installed: local.installedBuild,
                    ))
              : target.releaseOrder <= local.releaseOrder) ||
          target.releaseOrder < highestOrder ||
          v['size'] is! int ||
          (v['size'] as int) < 1 ||
          (v['size'] as int) > maximumArtifactBytes ||
          v['sha256'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(v['sha256'] as String) ||
          v['min_api_version'] is! int ||
          (v['min_api_version'] as int) < 1 ||
          (v['min_api_version'] as int) > 1 ||
          v['min_updater_version'] != 1 ||
          v['min_os_version'] is! String ||
          !_atLeast(environment.osVersion, v['min_os_version'] as String) ||
          v['expires_at'] is! String ||
          !(DateTime.tryParse(v['expires_at'] as String)
                  ?.isAfter(environment.now ?? DateTime.now().toUtc()) ??
              false)) {
        throw const ArtifactFailure('identity');
      }
      final expected = selector.platform == 'macos'
          ? 'sparkle_zip'
          : 'velopack_nupkg';
      if (v['package_type'] != expected ||
          v['download_url'] is! String ||
          !officialArtifactUrl(v['download_url'] as String)) {
        throw const ArtifactFailure('source');
      }
      if (selector.platform == 'macos' &&
          (v['native_signature'] is! String ||
              base64Decode(v['native_signature'] as String).length != 64)) {
        throw const ArtifactFailure('native_signature');
      }
      return VerifiedInstallArtifact._(envelope, Map.unmodifiable(v));
    } on ArtifactFailure {
      rethrow;
    } catch (_) {
      throw const ArtifactFailure('malformed');
    }
  }
}

bool officialArtifactUrl(String raw) {
  final u = Uri.tryParse(raw);
  if (u == null ||
      raw.length > 2048 ||
      u.scheme != 'https' ||
      u.host != 'github.com' ||
      u.userInfo.isNotEmpty ||
      u.hasQuery ||
      u.hasFragment ||
      (u.hasPort && u.port != 443)) {
    return false;
  }
  final prefix = 'https://github.com/BOOHTACORD/BOOHTACORD/releases/download/';
  if (!raw.startsWith(prefix)) return false;
  final parts = raw.substring(prefix.length).split('/');
  return parts.length == 2 &&
      parts.every(
        (s) =>
            RegExp(r'^[A-Za-z0-9_][A-Za-z0-9._-]{0,190}$').hasMatch(s) &&
            s != '.' &&
            s != '..',
      );
}

bool _atLeast(String current, String minimum) {
  if (!RegExp(r'^\d+(\.\d+){0,3}$').hasMatch(minimum) ||
      !RegExp(r'^\d+(\.\d+){0,3}$').hasMatch(current)) {
    return false;
  }
  final a = current.split('.').map(int.parse).toList(),
      b = minimum.split('.').map(int.parse).toList();
  for (var i = 0; i < 4; i++) {
    final d = (i < a.length ? a[i] : 0) - (i < b.length ? b[i] : 0);
    if (d != 0) return d > 0;
  }
  return true;
}
