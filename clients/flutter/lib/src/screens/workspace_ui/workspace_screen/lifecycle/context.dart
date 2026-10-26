import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceScreenStateContext extends State<WorkspaceScreen>
    with WidgetsBindingObserver, WindowListener {
  final workspaceMainSurfaceKey = GlobalKey(
    debugLabel: 'workspace-main-content',
  );
  final workspacePinnedMiniKey = GlobalKey(debugLabel: 'workspace-pinned-mini');
  bool workspaceShowMobileSidebar = false;
  bool workspaceInitialNavigationApplied = false;
  bool workspaceShowMembersDrawer = false;
  bool workspaceCapturingPttKey = false;
  String? workspaceCapturingVoiceShortcut;
  final workspaceShortcutAvailability = ShortcutAvailability();
  String? workspaceShortcutAccount;
  String? workspaceSelectedScreenIdentity;
  String? workspaceScreenWaitingToRestart;
  String? workspacePinnedScreenIdentity;
  ScreenFullscreenSelection? workspaceFullscreenScreenSelection;
  String? workspaceScreenSelectionVoiceChannelId;
  late ScreenSharePhase workspaceLastObservedScreenSharePhase;
  FocusNode? workspaceDrawerReturnFocus;
  FocusNode? workspaceWorkspacePanelReturnFocus;
  final workspaceSearchTriggerFocus = FocusNode(
    debugLabel: 'workspace-search-trigger',
  );
  WorkspacePanel? workspaceLastWorkspacePanel;
  String? get workspaceVisibleVoiceScreenIdentity;
  String? get workspaceVisiblePinnedScreenIdentity;
  String? get workspaceMiniScreenIdentity {
    final selected = workspaceSelectedScreenIdentity;
    return selected != null && selected.isNotEmpty
        ? selected
        : workspaceScreenWaitingToRestart;
  }

  void workspaceWorkspaceChanged();
  void workspaceSelectVoiceScreen(String? identity);
  void workspaceStopWatchingPinnedScreen();
  void workspaceSetFullscreenScreenSelection(
    ScreenFullscreenSelection? selection,
  );
  bool workspaceHandleHardwareKey(KeyEvent event);
  bool workspaceHandleVoiceShortcut(KeyDownEvent event);
  void workspaceToggleSearch();
  bool workspaceHandleSearchShortcut();
  void workspaceCloseDrawers();
  void workspaceCloseScrim();
  bool workspaceHandleEscape();
  void workspaceToggleNavigation();
  void workspaceToggleMembers();
  bool get workspaceTextInputFocused;
  void workspaceBeginPttKeyCapture();
  void workspaceBeginVoiceShortcutCapture(String action);
  void workspaceSetShortcutForeground(bool foreground);
  void workspaceMutateView(VoidCallback action) => setState(action);
}
