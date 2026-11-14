import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

/// Returns the audio publication belonging to a participant's screen share.
///
/// Older LiveKit senders may publish an audio track without its source enum.
/// Only infer that it is screen audio when the participant has an active screen
/// video and exactly one unlabelled audio publication; never guess between
/// multiple unknown audio tracks.
RemoteTrackPublication<RemoteAudioTrack>? screenShareAudioPublication(
  RemoteParticipant participant,
) {
  final audioPublications = participant.audioTrackPublications;
  final explicit = audioPublications
      .where(
        (publication) => publication.source == TrackSource.screenShareAudio,
      )
      .firstOrNull;
  if (explicit != null) return explicit;

  final hasScreenVideo = participant.videoTrackPublications.any(
    (publication) =>
        publication.source == TrackSource.screenShareVideo &&
        !publication.muted,
  );
  if (!hasScreenVideo) return null;

  final unlabelled = audioPublications
      .where((publication) => publication.source == TrackSource.unknown)
      .toList(growable: false);
  return unlabelled.length == 1 ? unlabelled.single : null;
}

bool isScreenShareAudioPublication(
  RemoteParticipant participant,
  RemoteTrackPublication publication,
) => screenShareAudioPublication(participant)?.sid == publication.sid;

/// True when an audio publication carries participant voice and may be silenced
/// by deafen. Explicit and reliably identified legacy screen audio stay active.
bool isVoiceAudioPublicationForDeafen(
  RemoteParticipant participant,
  RemoteTrackPublication publication,
) {
  if (publication.source == TrackSource.screenShareAudio) return false;
  return !isScreenShareAudioPublication(participant, publication);
}
