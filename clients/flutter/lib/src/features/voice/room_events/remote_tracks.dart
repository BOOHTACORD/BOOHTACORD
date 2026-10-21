import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import '../screen_preview/capture_policy.dart';
import '../screen_viewer/audio_publication.dart';
import '../screen_viewer/discovery.dart';
import '../screen_viewer/subscription_failure.dart';
import '../screen_viewer_presence/identity.dart';
import '../../../services/screen_share_diagnostics.dart';
import 'remote_participants.dart';
import 'refresh_voice_navigation.dart';
import 'remote_state_diagnostics.dart';

extension VoiceEventsRemoteTracks on VoiceController {
  void bindRemoteTracks(
    Room room,
    EventsListener<RoomEvent> listener,
    bool Function() owns,
  ) {
    bindRemoteParticipantEvents(room, listener, owns);
    listener.on<TrackSubscribedEvent>((event) {
      if (!owns()) return;
      if (!identical(this.room, room)) return;
      if (event.publication.source == TrackSource.screenShareVideo &&
          event.track is RemoteVideoTrack) {
        logRemoteVoiceState(
          room,
          ScreenShareDiagnosticEvent.remoteTrackSubscribed,
        );
        final viewerLeaseId = leaseId;
        final ownerLeaseId = voiceLeaseIdFromLiveKitIdentity(
          event.participant.identity,
        );
        if (viewerLeaseId != null && ownerLeaseId != null) {
          unawaited(
            screenViewerPresence.remoteTrackSubscribed(
              viewerLeaseId,
              ownerLeaseId,
              event.publication.sid,
            ),
          );
        }
        unawaited(
          captureSelectedRemoteScreenThumbnail(
            capture: () => captureRemoteThumbnail(
              room,
              event.participant,
              event.publication,
              event.track as RemoteVideoTrack,
            ),
            source: event.publication.source,
            isRemoteVideoTrack: event.track is RemoteVideoTrack,
            participantIdentity: event.participant.identity,
            selectedIdentity: selectedRemoteScreenViewerIdentity,
          ),
        );
      }
      if (event.track is RemoteAudioTrack) {
        if (deafened) unawaited(event.publication.disable());
        final source =
            isScreenShareAudioPublication(event.participant, event.publication)
            ? TrackSource.screenShareAudio
            : event.publication.source;
        unawaited(applySavedAudioVolume(event.participant, source));
      }
    });
    listener.on<TrackSubscriptionExceptionEvent>((event) {
      recoverRemoteScreenViewerAfterSubscriptionFailure(
        this,
        room,
        event,
        owns,
      );
    });
    listener.on<TrackPublishedEvent>((event) {
      if (!owns()) return;
      if (identical(this.room, room)) {
        if (shouldAutomaticallySubscribeRemoteTrack(event.publication.source)) {
          unawaited(setRemoteTrackSubscription(event.publication, true));
        } else if (event.publication.source == TrackSource.screenShareVideo) {
          logRemoteVoiceState(
            room,
            ScreenShareDiagnosticEvent.remoteTrackPublished,
          );
          if (event.participant.identity ==
              selectedRemoteScreenViewerIdentity) {
            subscribeRemoteScreenForViewing(room, event.participant.identity);
          }
        } else if (event.participant.identity ==
                selectedRemoteScreenViewerIdentity &&
            isScreenShareAudioPublication(
              event.participant,
              event.publication,
            )) {
          subscribeRemoteScreenAudioForViewing(event.publication);
        }
      }
      refreshRemoteVoiceNavigation(this, room, owns);
    });
    listener.on<TrackUnpublishedEvent>((event) {
      if (!owns()) return;
      if (event.publication.source == TrackSource.screenShareVideo) {
        logRemoteVoiceState(
          room,
          ScreenShareDiagnosticEvent.remoteTrackUnpublished,
        );
        final ownerLeaseId = voiceLeaseIdFromLiveKitIdentity(
          event.participant.identity,
        );
        if (ownerLeaseId != null) {
          unawaited(
            screenViewerPresence.remoteTrackUnsubscribed(
              ownerLeaseId,
              event.publication.sid,
            ),
          );
        }
        removeRemoteScreenThumbnail(
          event.participant.identity,
          publication: event.publication,
        );
        final replacement = event.participant.videoTrackPublications.any(
          (item) =>
              !identical(item, event.publication) &&
              isDiscoverableRemoteScreenPublication(item),
        );
        if (selectedRemoteScreenViewerIdentity == event.participant.identity &&
            !replacement) {
          unawaited(selectRemoteScreenForViewing(null));
        } else if (selectedRemoteScreenViewerIdentity ==
                event.participant.identity &&
            replacement) {
          subscribeRemoteScreenForViewing(room, event.participant.identity);
        }
      }
      refreshRemoteVoiceNavigation(this, room, owns);
    });
    listener.on<TrackMutedEvent>(
      (_) => refreshRemoteVoiceNavigation(this, room, owns),
    );
    listener.on<TrackUnmutedEvent>(
      (_) => refreshRemoteVoiceNavigation(this, room, owns),
    );
    listener.on<TrackSubscribedEvent>(
      (_) => refreshRemoteVoiceNavigation(this, room, owns),
    );
    listener.on<TrackUnsubscribedEvent>((event) {
      if (!owns()) return;
      if (event.publication.source == TrackSource.screenShareVideo) {
        logRemoteVoiceState(
          room,
          ScreenShareDiagnosticEvent.remoteTrackUnsubscribed,
        );
        final ownerLeaseId = voiceLeaseIdFromLiveKitIdentity(
          event.participant.identity,
        );
        if (ownerLeaseId != null) {
          unawaited(
            screenViewerPresence.remoteTrackUnsubscribed(
              ownerLeaseId,
              event.publication.sid,
            ),
          );
        }
      }
      refreshRemoteVoiceNavigation(this, room, owns);
    });
  }
}
