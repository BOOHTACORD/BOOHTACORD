import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

import 'dart:convert';

import '../../../app_state.dart';
import '../remote_lifecycle/controller.dart';
import 'account_controls.dart';
import 'device_controls.dart';
import 'local_panel.dart';
import 'conversation_rules.dart';

class NotificationSettingsPanel extends StatelessWidget {
  const NotificationSettingsPanel({super.key, required this.state});
  final AppState state;
  Future<void> confirm(
    BuildContext context,
    RemoteNotificationController remote,
  ) async {
    final version = remote.epoch;
    final cap = remote.capability;
    if (cap == null) return;
    final fingerprint = sha256
        .convert(
          utf8.encode(cap['installation_signing_public_key'] as String? ?? ''),
        )
        .toString()
        .substring(0, 16);
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подключить уведомления сервера?'),
        content: Text(
          'Сервер: ${cap['origin']}\nКлюч подключения: $fingerprint\n\nРазрешить этому серверу отправлять нейтральные уведомления на это устройство?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Разрешить'),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted && remote.epoch == version) {
      await remote.enable(askPermission: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remote = state.remoteNotifications;
    final prefs = remote.preferences;
    final settings = prefs?.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (settings != null) ...[
          NotificationAccountControls(
            settings: settings,
            busy: prefs!.busy,
            operatorAvailable:
                prefs.snapshot?['capability']['available'] == true,
            onEnabled: (value) => prefs.update((s) => s['enabled'] = value),
            onMode: (kind, value) =>
                prefs.update((s) => s[kind]['mode'] = value),
            onPause: (kind, value) => prefs.update(
              (s) => s[kind]['paused_until'] = value == 0
                  ? null
                  : DateTime.now()
                        .toUtc()
                        .add(Duration(minutes: value))
                        .toIso8601String(),
            ),
          ),
          NotificationDeviceControls(
            ready: remote.available,
            busy: remote.busy,
            status: remote.status,
            devices: remote.devices,
            onEnable: () => confirm(context, remote),
            onRevoke: remote.revoke,
          ),
          if (!settings['imported'])
            ExpansionTile(
              title: const Text('Перенести явные локальные настройки'),
              children: [
                const Text(
                  'Локальное включение не разрешает фоновую доставку. Явных правил бесед в прежнем клиенте не было; после переноса доставка остаётся выключенной.',
                ),
                OutlinedButton(
                  onPressed: prefs.busy
                      ? null
                      : () => prefs.importLegacy(!state.notificationsEnabled),
                  child: const Text('Подтвердить перенос'),
                ),
              ],
            ),
          ConversationNotificationRules(state: state),
          if (prefs.error != null)
            Semantics(liveRegion: true, child: Text(prefs.error!)),
          const SizedBox(height: 16),
        ],
        if (!remote.activeDevice)
          LocalNotificationPanel(state: state, hasRemote: settings != null),
        if (remote.error != null)
          Semantics(liveRegion: true, child: Text(remote.error!)),
      ],
    );
  }
}
