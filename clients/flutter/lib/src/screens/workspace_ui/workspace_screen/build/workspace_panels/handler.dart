import '../../../main_surface/component.dart';
import '../../../members_panel/component.dart';
import '../../../sidebar/component.dart';
import '../../../workspace_search_panel/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';
import '../../../../../widgets/pinned_screen_dock.dart';

extension WorkspaceScreenWorkspacePanelsRenderer
    on WorkspaceScreenStateContext {
  ExcludeFocus renderWorkspaceScreenWorkspacePanels(
    bool modalOverlayActive,
    bool wide,
    bool medium,
    bool pinnedMiniVisible,
    bool showMemberToggle,
    bool showPermanentMembers,
    bool searchPanelActive,
    bool searchPanelModal,
    Widget Function() pinnedMiniLayer,
  ) => ExcludeFocus(
    excluding: modalOverlayActive,
    child: Row(
      children: [
        SizedBox(
          key: const ValueKey('workspace-sidebar'),
          width:
              (wide
                  ? GcLayout.navWide
                  : medium
                  ? GcLayout.navMedium
                  : GcLayout.navSmall) -
              1,
          child: WorkspaceSidebar(
            state: widget.state,
            showVoiceDock: true,
            onSearch: workspaceToggleSearch,
            searchFocusNode: workspaceSearchTriggerFocus,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: PinnedScreenDock(
            mini: pinnedMiniVisible ? pinnedMiniLayer() : null,
            content: KeyedSubtree(
              key: const ValueKey('workspace-main-surface'),
              child: KeyedSubtree(
                key: workspaceMainSurfaceKey,
                child: WorkspaceMainSurface(
                  state: widget.state,
                  selectedScreenIdentity: workspaceVisibleVoiceScreenIdentity,
                  onSelectScreen: workspaceSelectVoiceScreen,
                  pinnedMiniVisible: pinnedMiniVisible,
                  fullscreenSelection: workspaceFullscreenScreenSelection,
                  onFullscreenSelectionChanged:
                      workspaceSetFullscreenScreenSelection,
                  pinnedScreenIdentity: workspaceVisiblePinnedScreenIdentity,
                  onOpenMembers: showMemberToggle
                      ? workspaceToggleMembers
                      : null,
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
        ),
        if (showPermanentMembers) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: (wide ? GcLayout.asideWide : GcLayout.asideMedium) - 1,
            child: WorkspaceMembersPanel(state: widget.state),
          ),
        ],
        if (searchPanelActive && !searchPanelModal) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: 380,
            child: WorkspaceWorkspaceSearchPanel(
              key: ValueKey(widget.state.workspace.searchSessionEpoch),
              state: widget.state,
            ),
          ),
        ],
      ],
    ),
  );
}
