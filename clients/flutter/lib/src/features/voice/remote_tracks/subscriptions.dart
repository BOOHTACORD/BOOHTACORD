import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

extension VoiceRemoteTracksSubscriptions on VoiceController {
  Future<void> syncRemoteVoiceSubscriptions(Room room) async {
    final updates = <Future<void>>[];
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.trackPublications.values) {
        final shouldSubscribe = shouldAutomaticallySubscribeRemoteTrack(
          publication.source,
        );
        if (publication.subscribed != shouldSubscribe) {
          updates.add(setRemoteTrackSubscription(publication, shouldSubscribe));
        }
      }
    }
    await Future.wait(updates);
  }

  Future<void> setRemoteTrackSubscription(
    RemoteTrackPublication publication,
    bool subscribed,
  ) async {
    try {
      if (subscribed) {
        await publication.subscribe();
      } else {
        await publication.unsubscribe();
      }
    } catch (_) {
      // Subscription failures leave the screen viewer on its avatar fallback.
    }
  }
}

bool shouldAutomaticallySubscribeRemoteTrack(TrackSource source) =>
    source == TrackSource.microphone;

bool shouldKeepRemoteTrackSubscribed(
  TrackSource source, {
  bool selectedScreenShare = false,
}) => source == TrackSource.microphone || selectedScreenShare;
