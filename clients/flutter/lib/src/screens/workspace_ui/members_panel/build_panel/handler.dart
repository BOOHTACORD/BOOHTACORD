import 'popover_surface/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateWorkspaceBuildPanelBinding
    on WorkspaceMembersPanelStateContext {
  @override
  Widget workspaceBuildPanel(BuildContext context) {
    return executeWorkspaceMembersPanelStateWorkspaceBuildPanel(context);
  }
}

extension WorkspaceMembersPanelStateWorkspaceBuildPanelAction
    on WorkspaceMembersPanelStateContext {
  Widget executeWorkspaceMembersPanelStateWorkspaceBuildPanel(
    BuildContext context,
  ) {
    final groups = [
      (
        title: 'В сети',
        members: state.members
            .where(
              (member) => state.memberPresence(member) == MemberPresence.online,
            )
            .toList(),
      ),
      (
        title: 'Не в сети',
        members: state.members
            .where(
              (member) =>
                  state.memberPresence(member) == MemberPresence.offline,
            )
            .toList(),
      ),
      (
        title: 'Статус неизвестен',
        members: state.members
            .where(
              (member) =>
                  state.memberPresence(member) == MemberPresence.unknown,
            )
            .toList(),
      ),
    ];

    return renderMembersPanelPopoverSurface(groups, context);
  }
}
