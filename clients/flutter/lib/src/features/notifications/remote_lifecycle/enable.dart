part of 'controller.dart';

extension RemoteNotificationEnable on RemoteNotificationController {
  Future<void> enable({required bool askPermission}) async {
    if (busy ||
        !available ||
        api == null ||
        scope == null ||
        capability == null) {
      return;
    }
    final version = epoch, attempt = ++operation;
    final key = scope!;
    final port = api!;
    busy = true;
    error = null;
    status = 'Регистрируем устройство…';
    changed();
    bool admitted() => current(version) && operation == attempt;
    try {
      await refreshDevices();
      if (!admitted()) return;
      await prepareCached(key, port, admitted, askPermission);
      if (!admitted()) return;
      enrollment?.close();
      enrollment = MobileEnrollment(
        api: port,
        driver: driver,
        config: config,
        storage: storage,
        inbox: inbox,
      );
      final result = await enrollment!.enable(
        capability!,
        key,
        admitted,
        askPermission: askPermission,
      );
      if (!admitted()) return;
      binding = result;
      local.remoteActive = true;
      status = result['permission'] == 'provisional'
          ? 'Активно с предварительным разрешением iOS; показ и звук ограничены системой'
          : 'Активно на этом устройстве';
      await refreshDevices();
      await openPending();
    } on PushUnavailable catch (failure) {
      if (admitted()) {
        error = pushFailureMessage(failure.reason);
        status = 'Регистрация не завершена';
        if (failure.reason == 'permission_denied') await disable();
      }
    } catch (_) {
      if (admitted()) {
        error = 'Регистрация не завершена. Проверьте соединение и повторите.';
        status = 'Регистрация не завершена';
      }
    } finally {
      if (current(version)) {
        busy = false;
        changed();
      }
    }
  }
}

String pushFailureMessage(String reason) => switch (reason) {
  'permission_denied' => 'Уведомления запрещены системой. Возврат разрешения сам по себе не включает доставку.',
  'apns_not_ready' =>
    'APNs ещё не выдал адрес устройству. Повторите после подключения к сети.',
  'installation_changed' => 'Ключ установки изменился. Требуется явное повторное подтверждение сервера.',
  'revoke_pending' =>
    'Отзыв предыдущей привязки не завершён. Проверьте сеть и повторите.',
  _ => 'Фоновая доставка сейчас недоступна. Проверьте настройки сервера и системное разрешение.',
};
