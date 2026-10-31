import '../../native_bindings.dart';
import '../../../../features/voice/voice_room_event_sounds.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceStopWatchingPinnedScreenBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceStopWatchingPinnedScreen() {
    executeWorkspaceScreenStateWorkspaceStopWatchingPinnedScreen();
  }
}

extension WorkspaceScreenStateWorkspaceStopWatchingPinnedScreenAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceStopWatchingPinnedScreen() {
    if (widget.state.selectedRemoteScreenViewerIdentity != null) {
      playVoiceRoomEventSound(
        enabled: widget.state.voiceRoomEventSoundsEnabled,
        event: VoiceRoomEventSound.streamViewStopped,
      );
    }
    unawaited(widget.state.selectRemoteScreenForViewing(null));
    workspaceMutateView(() {
      workspaceScreenWaitingToRestart = null;
      workspaceScreenSelectionVoiceChannelId = widget.state.voiceChannel?.id;
      workspaceSelectedScreenIdentity = '';
      workspacePinnedScreenIdentity = null;
    });
  }
}
