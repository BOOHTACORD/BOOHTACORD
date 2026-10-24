import '../../../main_surface/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceScreenDrawerSidebarRenderer on WorkspaceScreenStateContext {
  Positioned renderWorkspaceScreenDrawerSidebar(
    bool searchPanelModal,
    bool pinnedMiniVisible,
    bool showMemberToggle,
  ) => Positioned.fill(
    child: ExcludeFocus(
      excluding:
          workspaceShowMobileSidebar ||
          workspaceShowMembersDrawer ||
          searchPanelModal,
      child: KeyedSubtree(
        key: const ValueKey('workspace-main-surface'),
        child: KeyedSubtree(
          key: workspaceMainSurfaceKey,
          child: WorkspaceMainSurface(
            state: widget.state,
            selectedScreenIdentity: workspaceVisibleVoiceScreenIdentity,
            onSelectScreen: workspaceSelectVoiceScreen,
            pinnedMiniVisible: pinnedMiniVisible,
            fullscreenSelection: workspaceFullscreenScreenSelection,
            onFullscreenSelectionChanged: workspaceSetFullscreenScreenSelection,
            pinnedScreenIdentity: workspaceVisiblePinnedScreenIdentity,
            onToggleNavigation: workspaceToggleNavigation,
            onOpenMembers: showMemberToggle ? workspaceToggleMembers : null,
            onCapturePttKey: workspaceBeginPttKeyCapture,
            capturingPttKey: workspaceCapturingPttKey,
            onCaptureVoiceShortcut: workspaceBeginVoiceShortcutCapture,
            capturingVoiceShortcut: workspaceCapturingVoiceShortcut,
            hardwareKeyboardAvailable:
                workspaceShortcutAvailability.hardwareKeyboard,
          ),
        ),
      ),
    ),
  );
}
