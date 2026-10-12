import 'account_menu/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceUserFooterBuildBinding on WorkspaceUserFooterContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceUserFooterBuild(context);
  }
}

extension WorkspaceUserFooterBuildAction on WorkspaceUserFooterContext {
  Widget executeWorkspaceUserFooterBuild(BuildContext context) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GcLayout.userFooterHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    state.toggleWorkspacePanel(WorkspacePanel.profile);
                    onNavigate?.call();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      AuthenticatedAvatar(
                        state: state,
                        name: state.profile?.displayName ?? 'Вы',
                        avatarUrl: state.profile?.avatarUrl,
                        radius: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.profile?.displayName ?? 'Профиль',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              state.user!.isAdmin
                                  ? 'Администратор'
                                  : 'Участник',
                              style: const TextStyle(
                                color: GcColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              renderUserFooterAccountMenu(),
            ],
          ),
        ),
      );
}
