import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';
import '../profile_overlay.dart';

mixin WorkspaceMembersPanelStateWorkspaceShowMemberProfileBinding
    on WorkspaceMembersPanelStateContext {
  @override
  void workspaceShowMemberProfile(GuildMember member) {
    executeWorkspaceMembersPanelStateWorkspaceShowMemberProfile(member);
  }
}

extension WorkspaceMembersPanelStateWorkspaceShowMemberProfileAction
    on WorkspaceMembersPanelStateContext {
  void executeWorkspaceMembersPanelStateWorkspaceShowMemberProfile(
    GuildMember member,
  ) {
    workspaceProfileTriggerMemberId = member.id;
    workspaceProfileTriggerFocus.requestFocus();
    workspaceMutateView(() => workspaceProfileMemberId = member.id);
    final revision = state.workspace.selectionRevision;
    unawaited(() async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          state.workspace.selectionRevision != revision ||
          workspaceProfileMemberId != member.id)
        return;
      workspaceProfileTriggerFocus.requestFocus();
      await openMemberProfileOverlay(
        context: context,
        state: state,
        memberId: member.id,
        anchor: () {
          final box = workspaceProfileAnchorKey.currentContext
              ?.findRenderObject();
          if (box is RenderBox && box.attached)
            return box.localToGlobal(Offset.zero) & box.size;
          return Rect.fromLTWH(MediaQuery.sizeOf(context).width / 2, 80, 0, 0);
        },
        onContext: (value) => workspaceProfileDialogContext = value,
      ).whenComplete(() {
        workspaceProfileMemberId = null;
      });
    }());
  }
}
