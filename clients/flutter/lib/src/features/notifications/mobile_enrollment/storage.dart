import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class BindingStorage {
  Future<Map<String, dynamic>?> read(String scope);
  Future<void> write(String scope, Map<String, dynamic> value);
  Future<void> remove(String scope);
  Future<List<int>> deviceSeed(String namespace);
  Future<List<Map<String, dynamic>>> pendingRevokes();
  Future<void> saveRevokes(List<Map<String, dynamic>> pending);
}

class SecureBindingStorage implements BindingStorage {
  SecureBindingStorage({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage storage;
  static final _pending = <String, Future<void>>{};
  Future<T> _serial<T>(String key, Future<T> Function() action) {
    final result = (_pending[key] ?? Future<void>.value()).then(
      (_) => action(),
    );
    final tail = result.then<void>((_) {}).catchError((Object _) {});
    _pending[key] = tail;
    tail.whenComplete(() {
      if (identical(_pending[key], tail)) _pending.remove(key);
    });
    return result;
  }

  String _key(String scope) =>
      'notification-binding-v1:${sha256.convert(utf8.encode(scope))}';
  @override
  Future<Map<String, dynamic>?> read(String scope) =>
      _serial(_key(scope), () async {
        final raw = await storage.read(key: _key(scope));
        if (raw == null || raw.length > 16384) return null;
        try {
          final value = jsonDecode(raw);
          return value is Map<String, dynamic> ? value : null;
        } catch (_) {
          return null;
        }
      });
  @override
  Future<void> write(String scope, Map<String, dynamic> value) => _serial(
    _key(scope),
    () => storage.write(key: _key(scope), value: jsonEncode(value)),
  );
  @override
  Future<void> remove(String scope) =>
      _serial(_key(scope), () => storage.delete(key: _key(scope)));
  @override
  Future<List<int>> deviceSeed(String namespace) =>
      _serial('notification-device-key-v1:$namespace', () async {
        final key = 'notification-device-key-v1:$namespace';
        final raw = await storage.read(key: key);
        if (raw != null) {
          try {
            final bytes = base64Url.decode(raw);
            if (bytes.length == 32) return bytes;
          } catch (_) {}
        }
        final random = Random.secure();
        final seed = List<int>.generate(32, (_) => random.nextInt(256));
        await storage.write(key: key, value: base64Url.encode(seed));
        return seed;
      });
  @override
  Future<List<Map<String, dynamic>>> pendingRevokes() async {
    final raw = await storage.read(key: 'notification-revokes-v1');
    if (raw == null || raw.length > 16384) return [];
    try {
      final value = jsonDecode(raw);
      return value is List
          ? value.whereType<Map<String, dynamic>>().take(32).toList()
          : [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveRevokes(List<Map<String, dynamic>> pending) => storage.write(
    key: 'notification-revokes-v1',
    value: jsonEncode(pending.take(32).toList()),
  );
}
