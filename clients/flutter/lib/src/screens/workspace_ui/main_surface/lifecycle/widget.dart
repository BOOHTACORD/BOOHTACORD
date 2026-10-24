import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceMainSurface extends WorkspaceMainSurfaceContext
    with WorkspaceMainSurfaceBuildBinding {
  const WorkspaceMainSurface({
    super.key,
    required super.state,
    required super.selectedScreenIdentity,
    required super.onSelectScreen,
    required super.pinnedMiniVisible,
    required super.fullscreenSelection,
    required super.onFullscreenSelectionChanged,
    required super.pinnedScreenIdentity,
    super.onToggleNavigation,
    super.onOpenMembers,
    super.onCapturePttKey,
    super.capturingPttKey = false,
    super.onCaptureVoiceShortcut,
    super.capturingVoiceShortcut,
    super.hardwareKeyboardAvailable = false,
  });
}
