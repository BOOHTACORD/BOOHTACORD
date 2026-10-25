part of 'controller.dart';

extension RemoteNotificationStart on RemoteNotificationController {
  Future<void> start(String actor) async {
    epoch++;
    operation++;
    attentionTimer?.cancel();
    preferences?.dispose();
    enrollment?.close();
    account = actor;
    scope = null;
    binding = null;
    capability = null;
    devices = [];
    local.remoteActive = false;
    busy = false;
    error = null;
    hint = '';
    final version = epoch;
    api = NotificationApi(transport, actor);
    preferences = NotificationPreferencesController(
      NotificationPreferencesClient(api!.send),
      () => current(version),
    );
    preferences!.addListener(changed);
    await preferences!.load();
    if (!current(version) || preferences!.snapshot == null) {
      changed();
      return;
    }
    try {
      final descriptor = await api!.checked(
        'GET',
        '/notification-devices/capabilities',
      );
      if (!current(version)) return;
      final origin = Uri.parse(transport.session.baseUrl).origin;
      if (descriptor['version'] != 1 ||
          descriptor['account_id'] != actor ||
          descriptor['origin'] != origin ||
          descriptor['session_ref'] is! String) {
        throw const PushUnavailable('configuration');
      }
      capability = descriptor;
      scope = jsonEncode([
        origin,
        descriptor['installation_id'],
        actor,
        descriptor['session_ref'],
      ]);
      await refreshDevices();
      if (!current(version)) return;
      final cached = await storage.read(scope!);
      if (!current(version)) return;
      if (cached?['consent'] == true && cached?['phase'] == 'active') {
        final owns = devices.any(
          (d) =>
              d['id'] == cached!['id'] &&
              d['generation'] == cached['generation'] &&
              d['session_ref'] == descriptor['session_ref'] &&
              d['state'] == 'active',
        );
        if (owns) {
          binding = cached;
          local.remoteActive = true;
          if (available) await enable(askPermission: false);
        } else {
          await queueGrantRevoke(storage, config, cached);
          await storage.remove(scope!);
          await driver.disable(binding: cached?['id'] as String?);
          status =
              'Привязка отозвана или истекла. Включение выполняется отдельно.';
        }
      }
      if (!available && !activeDevice) {
        status =
            'Фоновая доставка недоступна в этой сборке или на этом сервере';
      }
      if (!current(version)) return;
      attentionTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(attention()),
      );
      await attention();
      await openPending();
      changed();
    } catch (_) {
      if (current(version)) {
        error = 'Не удалось проверить устройство уведомлений.';
        changed();
      }
    }
  }

  Future<void> refreshDevices() async {
    final version = epoch, port = api;
    if (port == null) return;
    final result = await port.checked('GET', '/notification-devices');
    if (current(version) && result['devices'] is List) {
      devices = (result['devices'] as List)
          .whereType<Map<String, dynamic>>()
          .take(100)
          .toList();
      changed();
    }
  }
}
