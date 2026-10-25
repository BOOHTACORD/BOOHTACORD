part of 'controller.dart';

extension RemoteNotificationEvents on RemoteNotificationController {
  void packet(Map<String, dynamic> data, {bool tap = false}) {
    if (disposed || inbox.accept(data)) return;
    final envelope = NotificationEnvelope.fromProvider(
      data,
      DateTime.now().toUtc(),
    );
    if (envelope == null) return;
    if (tap) {
      pendingTap = envelope;
      unawaited(openPending());
    } else if (foreground &&
        binding?['id'] == envelope.bindingRef &&
        binding?['generation'] == envelope.generation) {
      unawaited(foregroundNotice(envelope));
    }
  }

  Future<void> openPending() async {
    final envelope = pendingTap, port = api;
    if (envelope == null || port == null || capability == null) return;
    if (canNavigate?.call() == false) {
      error = 'Завершите изменения в настройках и вернитесь к беседе, чтобы открыть уведомление.';
      changed();
      return;
    }
    if (binding?['id'] != envelope.bindingRef ||
        binding?['generation'] != envelope.generation) {
      error = 'Уведомление относится к другому профилю или больше недоступно. Войдите в нужный аккаунт и выберите сервер.';
      changed();
      return;
    }
    if (handledTaps.contains(envelope.notificationRef)) return;
    pendingTap = null;
    handledTaps.add(envelope.notificationRef);
    if (handledTaps.length > 512) handledTaps.remove(handledTaps.first);
    final version = epoch;
    try {
      final target = await port.checked(
        'POST',
        '/notification-references/resolve',
        {'ref': envelope.notificationRef, 'generation': envelope.generation},
      );
      if (current(version)) {
        if (canNavigate?.call() == false) {
          handledTaps.remove(envelope.notificationRef);
          pendingTap = envelope;
          return;
        }
        await navigate?.call(target);
      }
    } catch (_) {
      if (current(version)) {
        error = 'Уведомление недоступно для текущего аккаунта.';
        changed();
      }
    }
  }

  Future<void> presented(String ref, int generation) async {
    try {
      await api?.checked('POST', '/notification-references/presented', {
        'ref': ref,
        'generation': generation,
      });
    } catch (_) {}
  }

  Future<void> foregroundNotice(NotificationEnvelope envelope) async {
    final version = epoch, key = scope;
    if (key == null) return;
    try {
      if (await NotificationDedup(local.preferences).claim(
        key,
        envelope.notificationRef,
        envelope.generation,
        envelope.expiresAt,
        () => current(version),
      )) {
        hint = envelope.title;
        changed();
      }
    } catch (_) {
      /* Never introduce another system presenter when storage fails. */
    }
    if (current(version)) {
      await presented(envelope.notificationRef, envelope.generation);
    }
  }

  Future<void> realtime(String? kind, Map<String, dynamic> data) async {
    if (kind == 'notification.preferences_changed') {
      await preferences?.load();
      return;
    }
    if (kind != 'notification.queued' ||
        !foreground ||
        !activeDevice ||
        data['version'] != 1 ||
        binding?['id'] != data['binding_ref'] ||
        binding?['generation'] != data['generation']) {
      return;
    }
    final visible = visibleConversation?.call();
    if (visible?['conversation_id'] != data['conversation_id']) {
      hint = data['kind'] == 'DM'
          ? 'Новое личное сообщение'
          : 'Новая активность в канале';
      changed();
    }
    await presented(data['ref'] as String, data['generation'] as int);
  }
}
