import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

import '../../../core/platform/session_storage.dart';

import 'package:path/path.dart' as path;

String desktopScope(String origin, String account) =>
    crypto.sha256.convert(utf8.encode('$origin\u0000$account')).toString();

/// Encrypted, bounded local state, entirely outside the replaced application.
/// Secure storage holds only the random encryption key; no credentials are copied.
class DesktopCheckpointStore {
  DesktopCheckpointStore(this.root, {Future<SecretKey> Function()? key})
    : _key = key ?? _secureKey;
  final Directory root;
  final Future<SecretKey> Function() _key;
  Future<SecretKey>? _cachedKey;
  Future<SecretKey> _loadKey() => _cachedKey ??= _key();
  final Map<String, Future<void>> _writes = {};
  static Future<SecretKey> _secureKey() async {
    final storage = sessionStorage();
    const name = 'boohtacord.desktop-update-state-key.v1';
    var encoded = await storage.read(key: name);
    if (encoded == null) {
      final key = await AesGcm.with256bits().newSecretKey();
      encoded = base64Encode(await key.extractBytes());
      await storage.write(key: name, value: encoded);
    }
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) throw const FormatException('checkpoint_key');
    return SecretKey(bytes);
  }

  File _file(String scope, String kind) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(scope) ||
        !['restart', 'workspace'].contains(kind)) {
      throw const FormatException('checkpoint_scope');
    }
    return File(path.join(root.path, '$scope-$kind.json'));
  }

  Future<void> save(String scope, String kind, Map<String, dynamic> value) {
    final id = '$scope:$kind';
    final previous = _writes[id] ?? Future<void>.value();
    final work = previous
        .catchError((Object _) {})
        .then((_) => _save(scope, kind, value));
    _writes[id] = work;
    return work;
  }

  Future<void> _save(
    String scope,
    String kind,
    Map<String, dynamic> value,
  ) async {
    if (_containsCredential(value)) {
      throw const FormatException('checkpoint_credentials');
    }
    final clear = utf8.encode(
      jsonEncode({'schema_version': 1, 'scope': scope, 'state': value}),
    );
    if (clear.length > 1024 * 1024) {
      throw const FormatException('checkpoint_size');
    }
    await root.create(recursive: true);
    if (Platform.isMacOS) await Process.run('/bin/chmod', ['700', root.path]);
    final sealed = await AesGcm.with256bits().encrypt(
      clear,
      secretKey: await _loadKey(),
      aad: utf8.encode('$scope:$kind'),
    );
    final file = _file(scope, kind),
        temp = File('${_file(scope, kind).path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'nonce': base64Encode(sealed.nonce),
        'ciphertext': base64Encode(sealed.cipherText),
        'mac': base64Encode(sealed.mac.bytes),
      }),
      flush: true,
    );
    await temp.rename(file.path);
  }

  Future<Map<String, dynamic>?> read(String scope, String kind) async {
    try {
      await _writes['$scope:$kind'];
      final file = _file(scope, kind);
      if (await file.length() > 1500000) return null;
      final encoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(encoded['ciphertext'] as String),
          nonce: base64Decode(encoded['nonce'] as String),
          mac: Mac(base64Decode(encoded['mac'] as String)),
        ),
        secretKey: await _loadKey(),
        aad: utf8.encode('$scope:$kind'),
      );
      final value = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      if (value['schema_version'] != 1 || value['scope'] != scope) return null;
      return value['state'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> consume(
    String scope,
    String transaction,
    String actualRelease,
    String actualBuild,
  ) async {
    final value = await read(scope, 'restart');
    if (value == null ||
        value['transaction'] != transaction ||
        value['expected_release'] != actualRelease ||
        value['expected_build'] != actualBuild) {
      return null;
    }
    final expires = DateTime.tryParse(value['expires_at'] as String? ?? '');
    if (expires == null || expires.isBefore(DateTime.now().toUtc())) {
      return null;
    }
    // Rename before handing state to callers: a second launch cannot replay it.
    final consumed = File('${_file(scope, 'restart').path}.consumed');
    await _file(scope, 'restart').rename(consumed.path);
    await consumed.delete();
    return value;
  }
}

bool _containsCredential(Object? value) {
  if (value is Map) {
    for (final key in value.keys) {
      if (RegExp(
        r'(token|password|cookie|authorization|credential|secret)',
        caseSensitive: false,
      ).hasMatch(key.toString())) {
        return true;
      }
      if (_containsCredential(value[key])) return true;
    }
  }
  if (value is List) return value.any(_containsCredential);
  return false;
}
