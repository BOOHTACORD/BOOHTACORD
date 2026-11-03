import '../participant_muted/component.dart';
import '../participant_name/component.dart';
import '../voice_navigation_member_row/component.dart';
import '../voice_participant_account_id/component.dart';
import '../native_bindings.dart';

class WorkspaceVoiceNavigationMembers extends StatelessWidget {
  const WorkspaceVoiceNavigationMembers({
    super.key,
    required this.state,
    required this.localParticipant,
    required this.remoteParticipants,
  });

  final AppState state;
  final LocalParticipant localParticipant;
  final Iterable<RemoteParticipant> remoteParticipants;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(40, 4, 8, 8),
    child: Column(
      children: [
        for (final participant in remoteParticipants) ...[
          const SizedBox(height: 4),
          WorkspaceVoiceNavigationMemberRow(
            state: state,
            name: workspaceParticipantName(participant),
            accountId: workspaceVoiceParticipantAccountId(participant),
            muted: workspaceParticipantMuted(participant),
            speaking:
                participant.isSpeaking &&
                !workspaceParticipantMuted(participant),
            screenSharing: participant.videoTrackPublications.any(
              (publication) =>
                  publication.source == TrackSource.screenShareVideo &&
                  !publication.muted,
            ),
          ),
        ],
        if (remoteParticipants.isNotEmpty) const SizedBox(height: 4),
        WorkspaceVoiceNavigationMemberRow(
          state: state,
          name: state.profile?.displayName.trim().isNotEmpty == true
              ? state.profile!.displayName
              : 'Вы',
          accountId: state.user?.accountId,
          muted: state.microphoneMuted,
          microphoneUnavailable: state.microphoneUnavailable,
          deafened: state.deafened,
          speaking: localParticipant.isSpeaking,
          screenSharing: state.screenSharePhase == ScreenSharePhase.sharing,
        ),
      ],
    ),
  );
}
