import '../../native_bindings.dart';

abstract class WorkspacePinnedScreenMiniPlayerContext extends StatelessWidget {
  const WorkspacePinnedScreenMiniPlayerContext({
    super.key,
    required this.state,
    required this.identity,
    required this.selectedIdentity,
    required this.pinnedMiniVisible,
    required this.fullscreenSelection,
    required this.onReturnToVoice,
    required this.onStopWatching,
    this.onFullscreenSelectionChanged,
  });
  final AppState state;
  final String identity;
  final String? selectedIdentity;
  final bool pinnedMiniVisible;
  final ScreenFullscreenSelection? fullscreenSelection;
  final VoidCallback onReturnToVoice;
  final VoidCallback onStopWatching;
  final ValueChanged<ScreenFullscreenSelection?>? onFullscreenSelectionChanged;
}
