import '../../../participant_member/component.dart';
import '../../../participant_muted/component.dart';
import '../../../participant_name/component.dart';
import '../../../voice_participant_account_id/component.dart';
import '../../../voice_participant_card/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceParticipantRoomParticipantsGridRenderer
    on WorkspaceVoiceParticipantRoomContext {
  Widget renderVoiceParticipantRoomParticipantsGrid(int crossAxisCount) =>
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          key: const ValueKey('voice-participant-grid'),
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            participants.length + 1,
            (index) => SizedBox(
              width:
                  (constraints.maxWidth - 12 * (crossAxisCount - 1)) /
                  crossAxisCount,
              child: _participantCard(index),
            ),
          ),
        ),
      );
  Widget _participantCard(int index) {
    if (index == 0) {
      return WorkspaceVoiceParticipantCard(
        key: const ValueKey('voice-participant-card:self'),
        state: state,
        name: state.profile?.displayName.trim().isNotEmpty == true
            ? state.profile!.displayName
            : 'Вы',
        avatarUrl: state.profile?.avatarUrl,
        muted: state.microphoneMuted,
        microphoneUnavailable: state.microphoneUnavailable,
        deafened: state.deafened,
        speaking: room?.localParticipant?.isSpeaking ?? false,
        isLocal: true,
        watchingScreen: state.voice.screenViewerAccountIds.any(
          (id) => id.toLowerCase() == state.user?.accountId.toLowerCase(),
        ),
        hasScreen: state.screenSharePhase == ScreenSharePhase.sharing,
        onScreenTap: state.screenSharePhase == ScreenSharePhase.sharing
            ? () => onScreenSelected(null)
            : null,
      );
    }
    final participant = participants[index - 1];
    final volume = state.participantVolume(participant);
    final hasScreen = participant.videoTrackPublications.any(
      (publication) =>
          publication.source == TrackSource.screenShareVideo &&
          !publication.muted,
    );
    return WorkspaceVoiceParticipantCard(
      key: ValueKey('voice-participant-card:${participant.sid}'),
      state: state,
      name: workspaceParticipantName(participant),
      avatarUrl: workspaceParticipantMember(state, participant)?.avatarUrl,
      muted: workspaceParticipantMuted(participant),
      speaking: participant.isSpeaking,
      volume: volume,
      onVolumeChanged: volume == null
          ? null
          : (level) =>
                unawaited(state.setParticipantVolume(participant, level)),
      hasScreen: hasScreen,
      watchingScreen: state.voice.screenViewerAccountIds.any(
        (id) =>
            id.toLowerCase() ==
            workspaceVoiceParticipantAccountId(participant)?.toLowerCase(),
      ),
      onScreenTap: hasScreen
          ? () => onScreenSelected(participant.identity)
          : null,
    );
  }
}
