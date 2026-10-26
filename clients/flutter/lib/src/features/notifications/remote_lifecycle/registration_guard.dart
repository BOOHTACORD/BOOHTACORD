part of 'controller.dart';

extension RemoteRegistrationGuard on RemoteNotificationController {
  Future<void> prepareCached(
    String key,
    NotificationApi port,
    bool Function() admitted,
    bool askPermission,
  ) async {
    var cached = await storage.read(key);
    if (!admitted()) return;
    if (cached != null && cached['phase'] != 'active') {
      final meta = devices
          .where(
            (d) =>
                d['id'] == cached?['id'] ||
                d['instance_id'] == cached?['instance_id'],
          )
          .firstOrNull;
      if (meta != null && meta['session_ref'] == capability?['session_ref']) {
        cached = {
          ...cached,
          'id': meta['id'],
          'instance_id': meta['instance_id'],
          'generation': meta['generation'],
        };
        await storage.write(key, cached);
        if (!admitted()) return;
      }
    }
    if (cached?['phase'] == 'active') {
      final meta = devices.where((d) => d['id'] == cached?['id']).firstOrNull;
      if (meta == null ||
          meta['state'] != 'active' ||
          meta['generation'] != cached?['generation']) {
        local.remoteActive = false;
        binding = null;
        await queueGrantRevoke(storage, config, cached);
        await driver.disable(binding: cached?['id'] as String?);
        if (!admitted()) return;
        if (!askPermission) throw const PushUnavailable('revoked');
        cached = meta == null
            ? <String, dynamic>{}
            : {
                'id': meta['id'],
                'instance_id': meta['instance_id'],
                'generation': meta['generation'],
                'phase': 'disabled',
                'consent': false,
              };
        await storage.write(key, cached);
      }
    }
    if (cached?['phase'] == 'disabled') {
      final meta = devices.where((d) => d['id'] == cached?['id']).firstOrNull;
      if (meta != null && meta['state'] == 'active') {
        await port.checked('DELETE', '/notification-devices/${meta['id']}', {
          'expected_generation': meta['generation'],
        });
        if (!admitted()) return;
        await storage.write(key, {
          'id': meta['id'],
          'instance_id': meta['instance_id'],
          'generation': (meta['generation'] as int) + 1,
          'phase': 'disabled',
          'consent': false,
        });
      }
    }
  }
}
