import 'package:flutter/material.dart';

import 'mode_items.dart';

class NotificationAccountControls extends StatelessWidget {
  const NotificationAccountControls({
    super.key,
    required this.settings,
    required this.busy,
    required this.operatorAvailable,
    required this.onEnabled,
    required this.onMode,
    required this.onPause,
  });
  final Map<String, dynamic> settings;
  final bool busy, operatorAvailable;
  final ValueChanged<bool> onEnabled;
  final void Function(String, String) onMode;
  final void Function(String, int) onPause;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Фоновые уведомления',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const Text(
        'Настройки аккаунта, оператора и разрешение устройства действуют отдельно. Содержимое сообщений остаётся в приложении.',
      ),
      if (!operatorAvailable)
        Semantics(
          liveRegion: true,
          child: const Text('Оператор отключил доставку уведомлений.'),
        ),
      CheckboxListTile(
        key: const ValueKey('notification-account-enabled'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Разрешить фоновые уведомления для аккаунта'),
        value: settings['enabled'] == true,
        onChanged: busy ? null : (v) => onEnabled(v == true),
      ),
      for (final kind in ['dm', 'text']) ...[
        Text(kind == 'dm' ? 'Личные сообщения' : 'Текстовые каналы'),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          isDense: false,
          itemHeight: null,
          key: ValueKey('notification-mode-$kind'),
          initialValue: (settings[kind] as Map)['mode'] as String,
          decoration: const InputDecoration(labelText: 'Уведомлять'),
          items: notificationModeItems,
          onChanged: busy
              ? null
              : (value) {
                  if (value != null) onMode(kind, value);
                },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          isExpanded: true,
          isDense: false,
          itemHeight: null,
          initialValue: 0,
          decoration: const InputDecoration(labelText: 'Пауза'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Возобновить / без паузы')),
            DropdownMenuItem(value: 15, child: Text('15 минут')),
            DropdownMenuItem(value: 60, child: Text('1 час')),
            DropdownMenuItem(value: 480, child: Text('8 часов')),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value != null) onPause(kind, value);
                },
        ),
        if ((settings[kind] as Map)['paused_until'] != null)
          Text(
            'Пауза до ${DateTime.tryParse((settings[kind] as Map)['paused_until'] as String)?.toLocal()}',
          ),
        const SizedBox(height: 12),
      ],
    ],
  );
}
