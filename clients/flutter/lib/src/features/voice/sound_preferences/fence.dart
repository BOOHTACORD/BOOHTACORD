import 'dart:async';
import 'dart:convert';

import 'schema.dart';

abstract interface class SoundFenceStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SoundFenceReceipt {
  SoundFenceReceipt._(this._versions);
  final Map<String, int> _versions;
}

class SoundPreferenceFence {
  SoundPreferenceFence(this.storage, String origin, String account)
    : key =
          'voice-sound-pending-off:v1:${base64UrlEncode(utf8.encode(jsonEncode([Uri.parse(origin).origin, account])))}';
  final SoundFenceStorage storage;
  final String key;
  Map<String, dynamic>? _pending;
  final Map<String, int> _versions = {};
  int _next = 0;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<Map<String, dynamic>> _read() async {
    if (_pending != null) return _pending!;
    try {
      final raw = await storage.read(key);
      if (raw == null) return _pending = {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      for (final entry in decoded.entries) {
        if (soundFlags.contains(entry.key) && entry.value == false) continue;
        if (entry.key == 'volume' &&
            entry.value is int &&
            entry.value >= 0 &&
            entry.value <= 100) {
          continue;
        }
        throw const FormatException();
      }
      return _pending = Map.of(decoded);
    } catch (_) {
      return _pending = {'enabled': false};
    }
  }

  Future<Map<String, dynamic>> apply(Map<String, dynamic> settings) {
    final snapshot = Map<String, dynamic>.of(settings);
    return _serial(() async {
      final restrictions = await _read();
      final result = snapshot;
      for (final entry in restrictions.entries) {
        if (entry.key == 'volume') {
          if ((entry.value as int) < (result['volume'] as int)) {
            result['volume'] = entry.value;
          }
        } else {
          result[entry.key] = false;
        }
      }
      return result;
    });
  }

  Future<SoundFenceReceipt> restrict(
    Map<String, dynamic> change,
    Map<String, dynamic> current,
  ) {
    change = Map<String, dynamic>.of(change);
    current = Map<String, dynamic>.of(current);
    return _serial(() async {
      validateSoundChanges(change);
      final pending = await _read();
      final versions = <String, int>{};
      for (final entry in change.entries) {
        if (soundFlags.contains(entry.key) && entry.value == false) {
          pending[entry.key] = false;
        } else if (entry.key == 'volume' &&
            (entry.value as int) < (current['volume'] as int)) {
          final previous = pending['volume'] as int? ?? 100;
          if ((entry.value as int) < previous) pending['volume'] = entry.value;
        } else {
          continue;
        }
        versions[entry.key] = _versions[entry.key] = ++_next;
      }
      await storage.write(key, jsonEncode(pending));
      return SoundFenceReceipt._(versions);
    });
  }

  Future<void> acknowledge(SoundFenceReceipt receipt) => _serial(() async {
    final pending = Map<String, dynamic>.of(await _read());
    for (final entry in receipt._versions.entries) {
      if (_versions[entry.key] == entry.value) pending.remove(entry.key);
    }
    await storage.write(key, jsonEncode(pending));
    _pending = pending;
  });
}
