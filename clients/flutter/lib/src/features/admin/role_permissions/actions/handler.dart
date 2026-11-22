import '../native_bindings.dart';
import '../lifecycle/context.dart';

extension RoleActionsAction on RolePermissionsContext {
  List<Widget> executeRenderRoleActions() => [
    if (role == GuildRole.administrator)
      const Text('Разрешения администратора обязательны и не изменяются.'),
    if (role == GuildRole.member)
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: saving || loading || denied ? null : loadDefaults,
            child: const Text('По умолчанию'),
          ),
          TextButton(
            onPressed: !dirty || saving || loading
                ? null
                : () => mutate(() => draft = Map.of(baseline)),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: !dirty || saving || loading || denied
                ? null
                : savePermissions,
            child: Semantics(
              liveRegion: saving,
              child: Text(saving ? 'Сохраняем…' : 'Сохранить'),
            ),
          ),
        ],
      ),
  ];
}
