import 'schema.dart';

const _prefsPath = '/api/v1/notification-preferences';
const _importPath = '/api/v1/notification-preferences/import';

class NotificationReply {
  final int status;
  final Map<String, dynamic> body;
  const NotificationReply(this.status, this.body);
}

typedef NotificationRequest = Future<NotificationReply> Function(
  String method,
  String path,
  Map<String, dynamic>? body,
);

class NotificationPreferenceError implements Exception {
  final int status;
  const NotificationPreferenceError(this.status);
  @override
  String toString() => 'NotificationPreferenceError($status)';
}

class NotificationPreferencesClient {
  final NotificationRequest send;
  bool _unsupported = false;

  NotificationPreferencesClient(this.send);

  Future<Map<String, dynamic>?> load() async {
    if (_unsupported) return null;
    final reply = await send('GET', _prefsPath, null);
    if (reply.status == 404 || reply.status == 405) {
      _unsupported = true;
      return null;
    }
    if (reply.status != 200) throw NotificationPreferenceError(reply.status);
    final body = reply.body;
    return validateNotificationSnapshot(body);
  }

  Future<Map<String, dynamic>> save(
    Map<String, dynamic> settings,
    int expectedRevision,
  ) async {
    if (_unsupported) throw const NotificationPreferenceError(503);
    final reply = await send('PUT', _prefsPath, {
      'settings': settings,
      'expected_revision': expectedRevision,
    });
    if (reply.status == 409) throw const NotificationPreferenceError(409);
    if (reply.status != 200) throw NotificationPreferenceError(reply.status);
    final body = reply.body;
    return validateNotificationSnapshot(body);
  }

  Future<Map<String, dynamic>> importExplicit(
    List<Map<String, dynamic>> overrides,
    bool localDisabled,
    int expectedRevision,
  ) async {
    if (_unsupported) throw const NotificationPreferenceError(503);
    final reply = await send('POST', _importPath, {
      'overrides': overrides,
      'local_disabled': localDisabled,
      'expected_revision': expectedRevision,
    });
    if (reply.status == 409) throw const NotificationPreferenceError(409);
    if (reply.status != 200) throw NotificationPreferenceError(reply.status);
    final body = reply.body;
    return validateNotificationSnapshot(body);
  }
}
