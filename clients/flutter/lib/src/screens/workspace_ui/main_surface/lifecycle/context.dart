import '../../native_bindings.dart';

abstract class WorkspaceMainSurfaceContext extends StatelessWidget {
  const WorkspaceMainSurfaceContext({
    super.key,
    required this.state,
    required this.selectedScreenIdentity,
    required this.onSelectScreen,
    required this.pinnedMiniVisible,
    required this.fullscreenSelection,
    required this.onFullscreenSelectionChanged,
    required this.pinnedScreenIdentity,
    this.onToggleNavigation,
    this.onOpenMembers,
    this.onCapturePttKey,
    this.capturingPttKey = false,
    this.onCaptureVoiceShortcut,
    this.capturingVoiceShortcut,
    this.hardwareKeyboardAvailable = false,
  });
  final AppState state;
  final String? selectedScreenIdentity;
  final ValueChanged<String?> onSelectScreen;
  final bool pinnedMiniVisible;
  final ScreenFullscreenSelection? fullscreenSelection;
  final ValueChanged<ScreenFullscreenSelection?> onFullscreenSelectionChanged;
  final String? pinnedScreenIdentity;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onOpenMembers;
  final VoidCallback? onCapturePttKey;
  final bool capturingPttKey;
  final ValueChanged<String>? onCaptureVoiceShortcut;
  final String? capturingVoiceShortcut;
  final bool hardwareKeyboardAvailable;
}
