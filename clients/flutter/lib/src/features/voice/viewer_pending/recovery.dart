import 'package:livekit_client/livekit_client.dart';

import '../lifecycle/controller.dart';

bool pendingScreenViewerRecoveryExhausted(
  VoiceController voice,
  RemoteTrackPublication? publication,
) {
  final generation = voice.selectedRemoteScreenViewerGeneration;
  return publication != null &&
      voice.remoteScreenViewerRecoveryExhausted &&
      voice.selectedRemoteScreenViewerIdentity ==
          generation?.participantIdentity &&
      publication.sid == generation?.publicationSid &&
      publication.participant.identity == generation?.participantIdentity;
}
