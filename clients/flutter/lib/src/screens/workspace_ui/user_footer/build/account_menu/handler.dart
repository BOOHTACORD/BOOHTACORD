import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension UserFooterAccountMenuRenderer on WorkspaceUserFooterContext {
  PopupMenuButton<String> renderUserFooterAccountMenu() =>
      PopupMenuButton<String>(
        tooltip: 'Настройки аккаунта',
        onSelected: (value) {
          if (value == 'logout') state.logout();
          if (value == 'profile') {
            state.toggleWorkspacePanel(WorkspacePanel.profile);
            onNavigate?.call();
          }
          if (value == 'audio') {
            state.toggleWorkspacePanel(WorkspacePanel.audio);
            onNavigate?.call();
          }
          if (value == 'admin') {
            state.toggleWorkspacePanel(WorkspacePanel.admin);
            onNavigate?.call();
          }
        },
        itemBuilder: (_) => [
          if (state.user?.isAdmin == true)
            const PopupMenuItem(
              value: 'admin',
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Администрирование')),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'audio',
            child: Row(
              children: [
                Icon(Icons.tune, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Настройки аудио')),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Профиль')),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Выйти')),
              ],
            ),
          ),
        ],
        icon: const Icon(Icons.settings_outlined, size: 20),
      );
}
