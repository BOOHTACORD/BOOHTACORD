import 'package:flutter/material.dart';

class NotificationDeviceControls extends StatelessWidget {
  const NotificationDeviceControls({
    super.key,
    required this.ready,
    required this.busy,
    required this.status,
    required this.devices,
    required this.onEnable,
    required this.onRevoke,
  });
  final bool ready, busy;
  final String status;
  final List<Map<String, dynamic>> devices;
  final Future<void> Function() onEnable;
  final Future<void> Function(Map<String, dynamic>) onRevoke;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(liveRegion: true, child: Text('Устройство: $status')),
      const Text(
        'Разрешение системы само по себе не подтверждает регистрацию устройства.',
      ),
      OutlinedButton(
        onPressed: ready && !busy ? onEnable : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: const Text(
          'Включить на этом устройстве',
          textAlign: TextAlign.center,
        ),
      ),
      for (final device in devices)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${device['transport'] == 'web_push' ? 'Браузер' : 'Мобильное устройство'} · ${deviceStateLabel(device['state'])}',
              ),
              OutlinedButton(
                onPressed: busy || device['state'] == 'revoked'
                    ? null
                    : () => onRevoke(device),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Отозвать'),
              ),
            ],
          ),
        ),
    ],
  );
}

String deviceStateLabel(Object? state) => switch (state) {
  'active' => 'активно',
  'registering' => 'ожидает регистрации',
  'revoked' => 'отозвано',
  'stale' => 'срок истёк',
  'permission_denied' => 'нет системного разрешения',
  'invalid' => 'маршрут недействителен',
  _ => 'состояние неизвестно',
};
