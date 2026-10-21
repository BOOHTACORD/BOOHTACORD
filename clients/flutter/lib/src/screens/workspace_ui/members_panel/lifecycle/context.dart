import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceMembersPanelStateContext
    extends State<WorkspaceMembersPanel> {
  final workspaceProfileAnchorKeys = <String, GlobalKey>{};
  final workspaceProfileFocusNodes = <String, FocusNode>{};
  GlobalKey workspaceAnchorFor(String id) =>
      workspaceProfileAnchorKeys.putIfAbsent(id, GlobalKey.new);
  FocusNode workspaceFocusFor(String id) => workspaceProfileFocusNodes
      .putIfAbsent(id, () => FocusNode(debugLabel: 'member-profile-trigger'));
  GlobalKey get workspaceProfileAnchorKey =>
      workspaceAnchorFor(workspaceProfileTriggerMemberId!);
  FocusNode get workspaceProfileTriggerFocus =>
      workspaceFocusFor(workspaceProfileTriggerMemberId!);
  BuildContext? workspaceProfileDialogContext;
  String? workspaceProfileMemberId;
  String? workspaceProfileTriggerMemberId;
  AppState get state;
  VoidCallback? get onClose;
  bool workspaceHandleHardwareKey(KeyEvent event);
  void workspaceShowMemberProfile(GuildMember member);
  void workspaceCloseMemberProfile();
  Widget workspaceBuildPanel(BuildContext context);
  Widget workspaceMemberRow(BuildContext context, GuildMember member);
  Widget workspaceMemberTile(
    BuildContext context,
    GuildMember member,
    MemberPresence memberPresence,
  );
  void workspaceMutateView(VoidCallback action) => setState(action);
}
