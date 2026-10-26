import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import 'publication_generation.dart';

bool matchesRemoteScreenViewerSubscriptionFailure(
  ScreenViewerPublicationGeneration generation,
  TrackSubscriptionExceptionEvent event,
) {
  final participantIdentity = event.participant?.identity;
  return event.sid == generation.publicationSid &&
      (participantIdentity == null ||
          participantIdentity == generation.participantIdentity);
}

void recoverRemoteScreenViewerAfterSubscriptionFailure(
  VoiceController voice,
  Room room,
  TrackSubscriptionExceptionEvent event,
  bool Function() owns,
) {
  final generation = voice.selectedRemoteScreenViewerGeneration;
  if (!owns() ||
      !identical(voice.room, room) ||
      generation == null ||
      !matchesRemoteScreenViewerSubscriptionFailure(generation, event)) {
    return;
  }
  final publication = voice.remoteScreenViewerRecoveryPublication;
  final isCurrent = voice.remoteScreenViewerRecoveryIsCurrent;
  if (publication == null ||
      isCurrent == null ||
      publication.sid != event.sid) {
    return;
  }
  retryRemoteScreenViewerSubscription(voice, publication, isCurrent);
}