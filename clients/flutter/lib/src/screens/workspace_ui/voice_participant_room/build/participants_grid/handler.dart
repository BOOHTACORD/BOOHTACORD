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
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context)
              .scale(1)
              .clamp(1.0, 2.0)
              .toDouble();
          final availableWidth =
              (constraints.maxWidth - 12 * (crossAxisCount - 1)) /
              crossAxisCount;
          final cardWidth = availableWidth.clamp(0.0, 280 * textScale);
          return Wrap(
            key: const ValueKey('voice-participant-grid'),
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: List.generate(
              participants.length + 1,
              (index) =>
                  SizedBox(width: cardWidth, child: _participantCard(index)),
            ),
          );
        },
      );
  Widget _participantCard(int index) {
    if (index == 0) {
      final localIdentity = room?.localParticipant?.identity;
      final quality = state.screenShareSelectedQuality;
      return WorkspaceVoiceParticipantCard(
        key: const ValueKey('voice-participant-card:self'),
        state: state,
        name: state.profile?.displayName.trim().isNotEmpty == true
            ? state.profile!.displayName
            : 'Вы',
        avatarUrl: state.profile?.avatarUrl,
        avatarIdentity: state.user?.accountId ?? localIdentity ?? 'local',
        muted: state.microphoneMuted,
        microphoneUnavailable: state.microphoneUnavailable,
        deafened: state.deafened,
        speaking: room?.localParticipant?.isSpeaking ?? false,
        isLocal: true,
        watchingScreen: state.voice.screenViewerAccountIds.any(
          (id) => id.toLowerCase() == state.user?.accountId.toLowerCase(),
        ),
        hasScreen: state.screenSharePhase == ScreenSharePhase.sharing,
        previewIdentity: localIdentity ?? 'local',
        previewThumbnail: localIdentity == null
            ? null
            : state.screenThumbnails[localIdentity],
        previewCaption: '${quality.resolution}p · ${quality.frameRate} FPS',
        onScreenTap: state.screenSharePhase == ScreenSharePhase.sharing
            ? () => onScreenSelected(null)
            : null,
      );
    }
    final participant = participants[index - 1];
    final volume = state.participantVolume(participant);
    var screenTrackName = '';
    final hasScreen = participant.videoTrackPublications.any((publication) {
      final activeScreen =
          publication.source == TrackSource.screenShareVideo &&
          !publication.muted;
      if (activeScreen) screenTrackName = publication.name;
      return activeScreen;
    });
    return WorkspaceVoiceParticipantCard(
      key: ValueKey('voice-participant-card:${participant.sid}'),
      state: state,
      name: workspaceParticipantName(participant),
      avatarUrl: workspaceParticipantMember(state, participant)?.avatarUrl,
      avatarIdentity:
          workspaceVoiceParticipantAccountId(participant) ??
          participant.identity,
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
      previewIdentity: participant.identity,
      previewThumbnail: state.screenThumbnails[participant.identity],
      previewCaption: _screenPreviewCaption(screenTrackName),
      onScreenTap: hasScreen
          ? () => onScreenSelected(participant.identity)
          : null,
    );
  }
}

String _screenPreviewCaption(String trackName) {
  final match = RegExp(r'screenshare-(\d+)p-(\d+)fps').firstMatch(trackName);
  if (match == null) return '';
  return '${match.group(1)}p · ${match.group(2)} FPS';
}
