import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controller.dart';
import 'coordinator.dart';

class DesktopUpdatePanel extends StatelessWidget {
  const DesktopUpdatePanel({
    super.key,
    required this.updates,
    required this.appBusy,
    this.inSettings = false,
  });
  final UpdateController updates;
  final bool appBusy, inSettings;
  Future<void> _restart(
    BuildContext context,
    DesktopUpdateCoordinator desktop,
  ) async {
    {
      final allowed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Перезапустить приложение?'),
          content: const Text(
            'Перезапуск прервёт звонок, демонстрацию экрана и незавершённые передачи файлов. Черновики будут сохранены. Демонстрацию после запуска нужно включить заново.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Продолжить работу'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Перезапустить'),
            ),
          ],
        ),
      );
      if (allowed != true) return;
    }
    await desktop.restart();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = updates.desktop;
    if (desktop == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: desktop,
      builder: (context, _) {
        if ([DesktopUpdatePhase.idle].contains(desktop.phase) ||
            (!inSettings && !desktop.bannerVisible)) {
          return const SizedBox.shrink();
        }
        final ready = desktop.phase == DesktopUpdatePhase.readyToRestart;
        final title = switch (desktop.phase) {
          DesktopUpdatePhase.downloading => 'Скачиваем обновление в фоне',
          DesktopUpdatePhase.verifying => 'Проверяем подпись и пакет',
          DesktopUpdatePhase.staging => 'Готовим обновление',
          DesktopUpdatePhase.readyToRestart =>
            'Версия ${desktop.artifact?.version ?? ''} готова. Перезапустите приложение, когда будет удобно.',
          DesktopUpdatePhase.applying =>
            'Сохраняем состояние и завершаем работу',
          DesktopUpdatePhase.restarting => 'Перезапускаем приложение',
          DesktopUpdatePhase.failed =>
            desktop.failure == 'installation_location'
                ? (Platform.isMacOS
                      ? 'Перенесите BOOHTACORD в папку «Программы», доступную вашему пользователю, и запустите его оттуда.'
                      : 'Один раз установите BOOHTACORD через Setup в профиль пользователя. После этого обновления будут доступны внутри приложения.')
                : desktop.failure == 'disk_space'
                ? 'Недостаточно свободного места для обновления.'
                : 'Не удалось подготовить обновление. Текущая версия сохранена.',
          DesktopUpdatePhase.completed => 'Новая версия запущена. Подключение к голосу и демонстрацию экрана при необходимости включите заново.',
          DesktopUpdatePhase.rolledBack =>
            'Предыдущая рабочая версия восстановлена',
          _ => 'Подготовка обновления приостановлена',
        };
        return Container(
          key: const ValueKey('desktop-update-transaction'),
          padding: const EdgeInsets.all(12),
          color: inSettings ? Colors.transparent : const Color(0xff173b63),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (desktop.phase == DesktopUpdatePhase.downloading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: desktop.total > 0
                      ? desktop.received / desktop.total
                      : null,
                ),
                Text(
                  '${(desktop.received / 1048576).toStringAsFixed(1)} / ${(desktop.total / 1048576).toStringAsFixed(1)} МБ',
                ),
                TextButton(
                  onPressed: desktop.cancel,
                  child: const Text('Приостановить'),
                ),
              ],
              Wrap(
                spacing: 8,
                children: [
                  if (desktop.failure == 'installation_location')
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://github.com/Egkurilov/BOOHTACORD/releases',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('Открыть официальные выпуски'),
                    ),
                  if (ready)
                    FilledButton(
                      onPressed: () => _restart(context, desktop),
                      child: const Text('Перезапустить'),
                    ),
                  if (updates.policy?.target != null &&
                      [
                        DesktopUpdatePhase.failed,
                        DesktopUpdatePhase.available,
                      ].contains(desktop.phase))
                    TextButton(
                      onPressed: () => desktop.prepare(updates.policy!.target!),
                      child: const Text('Повторить'),
                    ),
                  if (!inSettings && !desktop.working)
                    TextButton(
                      onPressed: desktop.later,
                      child: const Text('Позже'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
