import '../../native_bindings.dart';
import '../../../../features/voice/voice_room_event_sounds.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceSelectVoiceScreenBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceSelectVoiceScreen(String? identity) {
    executeWorkspaceScreenStateWorkspaceSelectVoiceScreen(identity);
  }
}

extension WorkspaceScreenStateWorkspaceSelectVoiceScreenAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceSelectVoiceScreen(String? identity) {
    final alreadyWatching =
        widget.state.selectedRemoteScreenViewerIdentity != null;
    if (!alreadyWatching && identity != null && identity.isNotEmpty) {
      playVoiceRoomEventSound(
        enabled: widget.state.voiceRoomEventSoundsEnabled,
        event: VoiceRoomEventSound.streamViewStarted,
      );
    }
    unawaited(widget.state.selectRemoteScreenForViewing(identity));
    workspaceMutateView(() {
      workspaceScreenWaitingToRestart = null;
      workspaceScreenSelectionVoiceChannelId = widget.state.voiceChannel?.id;
      workspaceSelectedScreenIdentity = identity;
      if (identity == null || identity.isEmpty) {
        workspacePinnedScreenIdentity = null;
      } else if (workspacePinnedScreenIdentity != null) {
        workspacePinnedScreenIdentity = identity;
      }
    });
  }
}
