import '../../participant_name/component.dart';
import '../../voice_participant_account_id/component.dart';
import '../../voice_viewer_streams_menu.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceScreenViewerWorkspaceStreamRailBinding
    on WorkspaceVoiceScreenViewerContext {
  @override
  Widget? get workspaceStreamRail {
    return executeWorkspaceVoiceScreenViewerWorkspaceStreamRail();
  }
}

extension WorkspaceVoiceScreenViewerWorkspaceStreamRailAction
    on WorkspaceVoiceScreenViewerContext {
  Widget? executeWorkspaceVoiceScreenViewerWorkspaceStreamRail() {
    if (screens.isEmpty && !localScreenAvailable) return null;
    final choices = [
      if (localScreenAvailable)
        VoiceScreenChoice.local(
          selected: showingLocalScreen,
          avatarIdentity: state.user?.accountId,
          avatarLabel: localName,
          thumbnail: screenThumbnailForIdentity(
            state.screenThumbnails,
            state.room?.localParticipant?.identity,
          ),
        ),
      for (final participant in screens)
        VoiceScreenChoice(
          identity: participant.identity,
          label: workspaceParticipantName(participant),
          selected: participant.identity == selectedIdentity,
          thumbnail: screenThumbnailForIdentity(
            state.screenThumbnails,
            participant.identity,
          ),
          accountId: workspaceVoiceParticipantAccountId(participant),
          avatarLabel: workspaceParticipantName(participant),
          hasAudio: screenShareAudioPublication(participant) != null,
        ),
    ];
    if (choices.length < 2) return null;
    return VoiceViewerStreamsMenu(
      choices: choices,
      onSelected: onScreenSelected,
    );
  }
}
