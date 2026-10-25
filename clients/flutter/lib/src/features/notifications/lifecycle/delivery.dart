import 'controller.dart';

extension NotificationDelivery on NotificationController {
  Future<void> deliver({
    required String eventId,
    required String body,
    required bool appIsForeground,
  }) async {
    final account = accountId;
    final active = admission();
    if (account == null ||
        remoteActive ||
        !initialized ||
        !active() ||
        !enabled ||
        appIsForeground ||
        permission != NativeNotificationPermission.granted) {
      return;
    }
    final inFlightKey = '$account:$eventId';
    if (!deliveriesInFlight.add(inFlightKey)) return;
    final key = seenKey(account);
    try {
      final seen = await preferences.getStringList(key) ?? const <String>[];
      if (!active() || !enabled || seen.contains(eventId)) return;
      await driver.show(
        id: notificationId(eventId),
        title: readTitle(),
        body: body,
      );
      if (!active()) return;
      final retained = [...seen, eventId];
      await preferences.setStringList(
        key,
        retained
            .skip(retained.length > 512 ? retained.length - 512 : 0)
            .toList(),
      );
    } catch (cause) {
      if (active()) {
        error = notificationFailure(cause);
        changed();
      }
    } finally {
      if (active()) deliveriesInFlight.remove(inFlightKey);
    }
  }
}
