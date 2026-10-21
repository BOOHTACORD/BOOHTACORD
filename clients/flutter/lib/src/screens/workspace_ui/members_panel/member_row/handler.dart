import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateWorkspaceMemberRowBinding
    on WorkspaceMembersPanelStateContext {
  @override
  Widget workspaceMemberRow(BuildContext context, GuildMember member) {
    return executeWorkspaceMembersPanelStateWorkspaceMemberRow(context, member);
  }
}

extension WorkspaceMembersPanelStateWorkspaceMemberRowAction
    on WorkspaceMembersPanelStateContext {
  Widget executeWorkspaceMembersPanelStateWorkspaceMemberRow(
    BuildContext context,
    GuildMember member,
  ) {
    final tile = workspaceMemberTile(
      context,
      member,
      state.memberPresence(member),
    );
    return SizedBox(
      key: workspaceAnchorFor(member.id),
      child: Focus(
        focusNode: workspaceFocusFor(member.id),
        onKeyEvent: (node, event) {
          if (node.hasPrimaryFocus &&
              event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            workspaceShowMemberProfile(member);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: tile,
      ),
    );
  }
}
