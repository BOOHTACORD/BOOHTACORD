import '../../../participant_name/component.dart';
import '../../../voice_participant_account_id/component.dart';
import '../../../voice_participant_strip/component.dart';
import '../../../native_bindings.dart';
import '../../../../../features/voice/viewer_pending/recovery.dart';
import '../../lifecycle/context.dart';

extension VoiceRoomEndedScreenRenderer on WorkspaceVoiceRoomStateContext {
  VoiceScreenEndedView renderVoiceRoomEndedScreen(
    RemoteTrackPublication<RemoteTrack>? selectedScreenPublication,
    VideoTrack? localScreenTrack,
    AppState state,
    Room? room,
    List<RemoteParticipant> screens,
    List<RemoteParticipant> participants,
  ) => VoiceScreenEndedView(
    connecting: selectedScreenPublication != null,
    recoveryExhausted: pendingScreenViewerRecoveryExhausted(
      state.voice,
      selectedScreenPublication,
    ),
    onRecoveryRetry: state.voice.retryRemoteScreenViewerRecovery,
    choices: [
      if (localScreenTrack != null)
        VoiceScreenChoice.local(
          selected: false,
          avatarIdentity: state.user?.accountId,
          avatarLabel: state.profile?.displayName ?? 'Вы',
          thumbnail: screenThumbnailForIdentity(
            state.screenThumbnails,
            room?.localParticipant?.identity,
          ),
        ),
      for (final participant in screens)
        VoiceScreenChoice(
          identity: participant.identity,
          label: workspaceParticipantName(participant),
          selected: false,
          accountId: workspaceVoiceParticipantAccountId(participant),
          avatarLabel: workspaceParticipantName(participant),
          thumbnail: screenThumbnailForIdentity(
            state.screenThumbnails,
            participant.identity,
          ),
          hasAudio: screenShareAudioPublication(participant) != null,
        ),
    ],
    participants: WorkspaceVoiceParticipantStrip(
      state: state,
      localName: state.profile?.displayName.trim().isNotEmpty == true
          ? state.profile!.displayName
          : 'Вы',
      localAvatarUrl: state.profile?.avatarUrl,
      localMuted: state.microphoneMuted,
      localSpeaking: room?.localParticipant?.isSpeaking ?? false,
      participants: participants,
    ),
    onScreenSelected: widget.onSelectScreen,
    onReturnToParticipants: () => widget.onSelectScreen(''),
  );
}
