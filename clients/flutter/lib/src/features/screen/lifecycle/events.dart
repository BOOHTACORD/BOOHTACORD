import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_share_metrics.dart';
import 'controller.dart';

extension ScreenShareEvents on ScreenShareController {
  void published(Room room, LocalVideoTrack track) {
    if (disposed ||
        !scope.capture().isActive ||
        !identical(readRoom(), room) ||
        phase == ScreenSharePhase.stopping) {
      return;
    }
    if (identical(activeTrack, track)) return;
    activeTrack = track;
    capturedContentVisibility.track(track.mediaStreamTrack.id);
    phase = ScreenSharePhase.sharing;
    error = null;
    if (nativeScreenMetricsPlatform(defaultTargetPlatform) != null) {
      metrics.start(track);
    }
    unawaited(thumbnail.start(room, track));
    descriptor.published();
    changed();
  }

  void unpublished(Room room, LocalVideoTrack? track) {
    if (disposed ||
        !identical(readRoom(), room) ||
        !identical(activeTrack, track)) {
      return;
    }
    activeTrack = null;
    capturedContentVisibility.track(null);
    if (phase == ScreenSharePhase.stopping) return;
    phase = ScreenSharePhase.idle;
    final identity = room.localParticipant?.identity;
    if (identity != null) thumbnails.remove(identity);
    // Serialize Android teardown with the next start.
    stopScreenShare();
  }
}
