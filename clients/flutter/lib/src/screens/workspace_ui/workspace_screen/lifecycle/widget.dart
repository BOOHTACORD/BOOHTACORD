import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.state,
    this.maintenanceBannerVisible = false,
    this.openNavigationInitially = false,
  });
  final AppState state;
  final bool maintenanceBannerVisible;
  final bool openNavigationInitially;

  @override
  State<WorkspaceScreen> createState() => WorkspaceScreenState();
}

class WorkspaceScreenState extends WorkspaceScreenStateContext
    with
        WorkspaceScreenStateWorkspaceVisibleVoiceScreenIdentityBinding,
        WorkspaceScreenStateWorkspaceVisiblePinnedScreenIdentityBinding,
        WorkspaceScreenStateInitStateBinding,
        WorkspaceScreenStateDidChangeDependenciesBinding,
        WorkspaceScreenStateDisposeBinding,
        WorkspaceScreenStateWorkspaceWorkspaceChangedBinding,
        WorkspaceScreenStateWorkspaceSelectVoiceScreenBinding,
        WorkspaceScreenStateWorkspaceStopWatchingPinnedScreenBinding,
        WorkspaceScreenStateWorkspaceSetFullscreenScreenSelectionBinding,
        WorkspaceScreenStateWorkspaceHandleHardwareKeyBinding,
        WorkspaceScreenStateWorkspaceHandleVoiceShortcutBinding,
        WorkspaceScreenStateWorkspaceToggleSearchBinding,
        WorkspaceScreenStateWorkspaceHandleSearchShortcutBinding,
        WorkspaceScreenStateWorkspaceCloseDrawersBinding,
        WorkspaceScreenStateWorkspaceCloseScrimBinding,
        WorkspaceScreenStateWorkspaceHandleEscapeBinding,
        WorkspaceScreenStateWorkspaceToggleNavigationBinding,
        WorkspaceScreenStateWorkspaceToggleMembersBinding,
        WorkspaceScreenStateWorkspaceTextInputFocusedBinding,
        WorkspaceScreenStateWorkspaceBeginPttKeyCaptureBinding,
        WorkspaceScreenStateWorkspaceBeginVoiceShortcutCaptureBinding,
        WorkspaceScreenStateDidChangeAppLifecycleStateBinding,
        WorkspaceScreenStateOnWindowFocusBinding,
        WorkspaceScreenStateOnWindowBlurBinding,
        WorkspaceScreenStateWorkspaceSetShortcutForegroundBinding,
        WorkspaceScreenStateBuildBinding {}
