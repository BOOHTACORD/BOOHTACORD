import '../../native_bindings.dart';

import '../lifecycle/context.dart';

extension SynchronizeScreenSelectionAction on WorkspaceScreenStateContext {
  void synchronizeScreenSelection() {
    if (workspaceShortcutAccount != widget.state.user?.accountId ||
        widget.state.workspacePanel != WorkspacePanel.audio) {
      if (workspaceCapturingVoiceShortcut != null) {
        workspaceMutateView(() => workspaceCapturingVoiceShortcut = null);
      }
      workspaceShortcutAccount = widget.state.user?.accountId;
    }
    final screenSharePhase = widget.state.screenSharePhase;
    final localScreenJustStarted = localScreenShareJustStarted(
      wasSharing:
          workspaceLastObservedScreenSharePhase == ScreenSharePhase.sharing,
      isSharing: screenSharePhase == ScreenSharePhase.sharing,
    );
    workspaceLastObservedScreenSharePhase = screenSharePhase;
    if (localScreenJustStarted &&
        (workspaceSelectedScreenIdentity != null ||
            workspacePinnedScreenIdentity != null)) {
      workspaceMutateView(() {
        workspaceSelectedScreenIdentity = null;
        workspacePinnedScreenIdentity = null;
        workspaceScreenWaitingToRestart = null;
        workspaceScreenSelectionVoiceChannelId = widget.state.voiceChannel?.id;
      });
      unawaited(widget.state.selectRemoteScreenForViewing(null));
    }
    final activeVoiceChannelId = widget.state.voiceChannel?.id;
    if ((workspaceSelectedScreenIdentity != null ||
            workspacePinnedScreenIdentity != null) &&
        !screenSelectionBelongsToVoiceChannel(
          selectionVoiceChannelId: workspaceScreenSelectionVoiceChannelId,
          activeVoiceChannelId: activeVoiceChannelId,
        )) {
      workspaceMutateView(() {
        workspaceSelectedScreenIdentity = null;
        workspacePinnedScreenIdentity = null;
        workspaceScreenSelectionVoiceChannelId = null;
        workspaceScreenWaitingToRestart = null;
      });
      unawaited(widget.state.selectRemoteScreenForViewing(null));
    }
    final roomForSelection = widget.state.room;
    final selectedIdentity = workspaceSelectedScreenIdentity;
    if (selectedIdentity != null &&
        selectedIdentity.isNotEmpty &&
        roomForSelection != null &&
        !(roomForSelection
                .remoteParticipants[selectedIdentity]
                ?.videoTrackPublications
                .any((item) => item.source == TrackSource.screenShareVideo) ??
            false)) {
      workspaceMutateView(() {
        workspaceScreenWaitingToRestart = selectedIdentity;
        workspaceSelectedScreenIdentity = '';
        workspacePinnedScreenIdentity = null;
      });
      unawaited(widget.state.selectRemoteScreenForViewing(null));
    }
    final waitingIdentity = workspaceScreenWaitingToRestart;
    if (waitingIdentity != null &&
        roomForSelection != null &&
        (roomForSelection
                .remoteParticipants[waitingIdentity]
                ?.videoTrackPublications
                .any((item) => item.source == TrackSource.screenShareVideo) ??
            false)) {
      workspaceMutateView(() {
        workspaceSelectedScreenIdentity = waitingIdentity;
        workspaceScreenWaitingToRestart = null;
      });
      unawaited(widget.state.selectRemoteScreenForViewing(waitingIdentity));
    }
  }
}
