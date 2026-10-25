import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../lifecycle/contracts.dart';

class NotificationDedup {
  NotificationDedup(this.storage);
  final NativeNotificationPreferences storage;
  static final _pending = <String, Future<void>>{};
  Future<bool> claim(
    String scope,
    String ref,
    int generation,
    DateTime expiry,
    bool Function() active,
  ) {
    final key =
        'boohtacord:remote-seen:v1:${sha256.convert(utf8.encode(scope))}';
    final result = (_pending[key] ?? Future<void>.value()).then((_) async {
      if (!active() || !expiry.isAfter(DateTime.now().toUtc())) return false;
      final records = await storage.getStringList(key) ?? [];
      if (!active()) return false;
      final now = DateTime.now().millisecondsSinceEpoch;
      final retained = <String>[];
      var duplicate = false;
      for (final record in records.take(512)) {
        final fields = record.split('|');
        if (fields.length != 3) continue;
        final until = int.tryParse(fields[2]);
        if (until == null || until <= now) continue;
        if (fields[0] == ref && fields[1] == '$generation') duplicate = true;
        retained.add(record);
      }
      if (duplicate) return false;
      retained.add('$ref|$generation|${expiry.millisecondsSinceEpoch}');
      if (!active()) return false;
      await storage.setStringList(
        key,
        retained
            .skip(retained.length > 512 ? retained.length - 512 : 0)
            .toList(),
      );
      return active();
    });
    final tail = result.then<void>((_) {}).catchError((Object _) {});
    _pending[key] = tail;
    tail.whenComplete(() {
      if (identical(_pending[key], tail)) _pending.remove(key);
    });
    return result;
  }
}
