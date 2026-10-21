import 'context.dart';
import '../handler_bindings.dart';

class WorkspacePinnedScreenMiniPlayer
    extends WorkspacePinnedScreenMiniPlayerContext
    with WorkspacePinnedScreenMiniPlayerBuildBinding {
  const WorkspacePinnedScreenMiniPlayer({
    super.key,
    required super.state,
    required super.identity,
    required super.selectedIdentity,
    required super.pinnedMiniVisible,
    required super.fullscreenSelection,
    required super.onReturnToVoice,
    required super.onStopWatching,
    super.onFullscreenSelectionChanged,
  });
}
