import 'package:flutter/material.dart';

import '../../../app_state.dart';
import '../../../services/native_notifications.dart';
import '../../../theme.dart';

class LocalNotificationPanel extends StatelessWidget {
  const LocalNotificationPanel({
    super.key,
    required this.state,
    required this.hasRemote,
  });
  final AppState state;
  final bool hasRemote;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        hasRemote
            ? 'Локальные уведомления открытого приложения'
            : 'Уведомления',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text(
        'Показываем общий текст нового сообщения, пока приложение неактивно. Содержимое личных сообщений не отображается.',
        style: TextStyle(color: GcColors.textSecondary),
      ),
      const SizedBox(height: 8),
      Semantics(
        liveRegion: true,
        child: Text(switch (state.notificationPermission) {
          NativeNotificationPermission.unavailable =>
            'Системные уведомления недоступны.',
          NativeNotificationPermission.denied =>
            'Уведомления запрещены в настройках системы.',
          NativeNotificationPermission.granted =>
            state.notificationsEnabled
                ? 'Уведомления включены.'
                : 'Уведомления выключены.',
        }),
      ),
      if (state.notificationError != null) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            state.notificationError!,
            style: const TextStyle(color: GcColors.danger),
          ),
        ),
      ],
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed:
              state.notificationPermission ==
                  NativeNotificationPermission.unavailable
              ? null
              : state.notificationsEnabled
              ? state.disableNotifications
              : state.enableNotifications,
          child: Text(
            state.notificationsEnabled
                ? 'Отключить уведомления'
                : 'Включить уведомления',
          ),
        ),
      ),
    ],
  );
}
