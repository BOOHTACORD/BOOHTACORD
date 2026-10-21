import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/screen_share_diagnostics.dart';
import '../lifecycle/controller.dart';
import '../../screen/lifecycle/controller.dart';

extension VoiceEventsLocalTracks on VoiceController {
  void bindLocalTracks(
    Room room,
    EventsListener<RoomEvent> listener,
    bool Function() owns,
  ) {
    listener.on<LocalTrackPublishedEvent>((event) {
      if (!owns()) return;
      if (!identical(this.room, room) ||
          event.publication.source != TrackSource.screenShareVideo) {
        return;
      }
      final ownerLeaseId = leaseId;
      if (ownerLeaseId != null) {
        unawaited(
          screenViewerPresence.localTrackPublished(
            ownerLeaseId,
            event.publication.sid,
          ),
        );
      }
      final track = event.publication.track;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.localPublished,
        platform: defaultTargetPlatform,
        trackEnabled: screenShareTrackEnabled(track),
        localScreenPublications: screenShareLocalPublicationCount(room),
      );
      if (track is LocalVideoTrack) screen.published(room, track);
    });
    listener.on<LocalTrackUnpublishedEvent>((event) {
      if (!owns()) return;
      if (event.publication.source != TrackSource.screenShareVideo) return;
      final ownerLeaseId = leaseId;
      if (ownerLeaseId != null) {
        unawaited(
          screenViewerPresence.localTrackUnpublished(
            ownerLeaseId,
            event.publication.sid,
          ),
        );
      }
      final track = event.publication.track;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.localUnpublished,
        platform: defaultTargetPlatform,
        trackEnabled: screenShareTrackEnabled(track),
        localScreenPublications: screenShareLocalPublicationCount(room),
      );
      screen.unpublished(room, track is LocalVideoTrack ? track : null);
    });
  }
}
