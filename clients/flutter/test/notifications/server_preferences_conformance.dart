import 'dart:io';

import 'package:boohtacord_desktop/src/features/notifications/server_preferences/client.dart';
import 'package:boohtacord_desktop/src/features/notifications/server_preferences/migration.dart';

Future<void> main() async {
  var calls = 0;
  final old = NotificationPreferencesClient((method, path, body) async {
    calls++;
    return const NotificationReply(404, {});
  });
  if (await old.load() != null || await old.load() != null || calls != 1) {
    throw StateError('Old server probe loop');
  }
  try {
    await old.save({}, 0);
    throw StateError('Unsupported mutation allowed');
  } on NotificationPreferenceError catch (error) {
    if (error.status != 503) rethrow;
  }
  if (calls != 1) throw StateError('Unsupported mutation sent');
  Map<String, dynamic>? sent;
  final snapshot = <String, dynamic>{
    'capability': {
      'version': 1,
      'available': false,
      'device_transport': 'unavailable',
    },
    'settings': {
      'version': 1,
      'revision': 7,
      'enabled': false,
      'imported': false,
      'dm': {'mode': 'all'},
      'text': {'mode': 'mentions'},
      'overrides': [],
    },
  };
  final client = NotificationPreferencesClient((method, path, body) async {
    sent = body;
    return NotificationReply(method == 'PUT' ? 409 : 200, snapshot);
  });
  if ((await client.load())?['settings']['revision'] != 7) {
    throw StateError('Snapshot schema mismatch');
  }
  try {
    await client.save(snapshot['settings'], 7);
    throw StateError('Conflict lost');
  } on NotificationPreferenceError catch (error) {
    if (error.status != 409) rethrow;
  }
  if (sent?['expected_revision'] != 7 ||
      sent?.containsKey('account_id') == true) {
    throw StateError('Unsafe mutation');
  }
  final preview = previewNativeNotificationMigration(false);
  if (!preview.localDisabled || preview.overrides.isNotEmpty) {
    throw StateError('Unsafe migration');
  }
  if (previewNativeNotificationMigration(null).overrides.isNotEmpty) {
    throw StateError('Implicit override imported');
  }
  stdout.writeln(
    'PASS: old server fallback, revision conflict, own actor, explicit migration',
  );
}
