part of 'controller.dart';

extension RemoteNotificationClear on RemoteNotificationController {
  Future<void> disable({bool signedOut = false}) async {
    operation++;
    local.remoteActive = false;
    inbox.clear();
    final old = binding;
    final key = scope;
    final port = api;
    binding = null;
    status = 'Отключено на этом устройстве';
    changed();
    if (key != null) {
      try {
        final cached = await storage.read(key);
        await queueGrantRevoke(storage, config, cached ?? old);
        final meta = cached ?? old;
        if (meta != null) {
          await storage.write(key, {
            'id': meta['id'],
            'instance_id': meta['instance_id'],
            'generation': meta['generation'],
            'phase': 'disabled',
            'consent': false,
          });
        }
      } catch (_) {
        error =
            'Отключено локально; отзыв будет повторён при следующем включении.';
      }
    }
    try {
      await driver.disable(binding: old?['id'] as String?);
    } catch (_) {
      /* Routing is already cleared; offline revoke stays queued. */
    }
    if (!signedOut && old != null && port != null) {
      try {
        await port.checked('DELETE', '/notification-devices/${old['id']}', {
          'expected_generation': old['generation'],
        });
      } catch (_) {}
    }
    if (available && port != null) {
      try {
        final client = MobileEnrollment(
          api: port,
          driver: driver,
          config: config,
          storage: storage,
          inbox: inbox,
        );
        try {
          await reconcileRevokes(storage, client.relay, config);
        } finally {
          client.close();
        }
      } catch (_) {}
    }
    changed();
  }

  Future<void> revoke(Map<String, dynamic> device) async {
    final port = api;
    if (port == null) return;
    if (device['id'] == binding?['id']) {
      await disable();
      await refreshDevices();
      return;
    }
    try {
      await port.checked('DELETE', '/notification-devices/${device['id']}', {
        'expected_generation': device['generation'],
      });
      await refreshDevices();
    } catch (_) {
      error = 'Не удалось отозвать устройство. Обновите список.';
      changed();
    }
  }

  Future<void> stop() async {
    final clearing = disable(signedOut: true);
    epoch++;
    operation++;
    attentionTimer?.cancel();
    preferences?.dispose();
    preferences = null;
    account = null;
    scope = null;
    capability = null;
    devices = [];
    enrollment?.close();
    enrollment = null;
    handledTaps.clear();
    pendingTap = null;
    await clearing;
    changed();
  }
}
