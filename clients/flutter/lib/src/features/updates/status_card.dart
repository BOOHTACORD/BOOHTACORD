import 'package:flutter/material.dart';

import '../../app_version.dart';
import '../../theme.dart';
import 'scope.dart';
import 'model.dart';
import 'action.dart';
import 'desktop/panel.dart';

class ClientUpdateStatusCard extends StatelessWidget {
  const ClientUpdateStatusCard({super.key});
  @override
  Widget build(BuildContext context) {
    final updates = UpdateScope.maybeOf(context);
    if (updates == null)
      return const Text(
        appVersionLabel,
        key: ValueKey('app-version-label'),
        style: TextStyle(color: GcColors.muted, fontSize: 12),
      );
    const labels = {
      UpdateResult.upToDate: 'Установлена актуальная версия',
      UpdateResult.updateAvailable: 'Доступно обновление',
      UpdateResult.currentAhead: 'Эта сборка новее опубликованной',
      UpdateResult.noPublishedTarget: 'Канал обновлений пока не настроен',
      UpdateResult.unsupportedEnvironment:
          'Новая версия требует другую версию ОС',
      UpdateResult.identityConflict: 'Не удалось подтвердить сборку приложения',
      UpdateResult.identityUnknown: 'Не удалось определить сборку приложения',
      UpdateResult.checkUnavailable: 'Не удалось проверить обновления',
    };
    return AnimatedBuilder(
      animation: updates,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: GcColors.border),
          const SizedBox(height: 24),
          const Text(
            'Версия приложения',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '$appVersionLabel · ${updates.result == null ? 'Ещё не проверено' : labels[updates.result]}${updates.stale ? ' · данные устарели' : ''}',
            style: const TextStyle(color: GcColors.textSecondary),
          ),
          Text(
            '${updates.identity.selector.platform} · ${updates.identity.selector.distribution} · ${updates.identity.selector.channel}',
            style: const TextStyle(color: GcColors.muted, fontSize: 12),
          ),
          if (updates.lastSuccessfulCheckAt != null)
            Text(
              'Последняя проверка: ${updates.lastSuccessfulCheckAt!.toLocal()}',
              style: const TextStyle(color: GcColors.muted, fontSize: 12),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: updates.status.name == 'checking'
                ? null
                : updates.manual,
            child: Text(
              updates.status.name == 'checking'
                  ? 'Проверяем…'
                  : 'Проверить обновления',
            ),
          ),
          if (updates.result == UpdateResult.updateAvailable)
            TextButton(
              onPressed: () =>
                  performUpdateAction(context, updates, appBusy: true),
              child: const Text('Обновить'),
            ),
          DesktopUpdatePanel(updates: updates, appBusy: true, inSettings: true),
          if (updates.error != null) ...[
            const SizedBox(height: 8),
            Text(
              updates.error!,
              style: const TextStyle(color: GcColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
