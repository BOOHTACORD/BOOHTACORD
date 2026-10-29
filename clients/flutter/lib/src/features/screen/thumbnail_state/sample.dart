import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_thumbnail.dart';
import 'controller.dart';

extension ScreenThumbnailSample on ScreenThumbnailController {
  Future<ScreenThumbnailCaptureResult?> sample(
    Room room,
    LocalVideoTrack track,
  ) async {
    await cleanup;
    final ticket = scope.capture();
    final expected = revision;
    final previewLease = leaseId;
    bool active() =>
        cleanup == null &&
        ticket.isActive &&
        expected == revision &&
        identical(this.track, track) &&
        identical(readRoom(), room) &&
        leaseId == previewLease &&
        isSharing();
    if (!active() || busy == expected) return null;
    busy = expected;
    ScreenThumbnailCaptureResult? result;
    try {
      result = await captureScreenThumbnailFrame(
        capture: () => queue.run(() => capture(track)),
        encode: encode,
        storeLocally: (thumbnail) {
          final identity = room.localParticipant?.identity;
          if (identity == null) return;
          thumbnails[identity] = thumbnail;
          if (previewLease != null) {
            previewUploader.offer(previewLease, thumbnail);
          }
          changed();
        },
        isActive: active,
      );
      if (active() && lastLoggedResult != result) {
        debugPrint('[screen-thumbnail] local=${result.name}');
        lastLoggedResult = result;
      }
    } catch (_) {
      // Thumbnail diagnostics must never interrupt the media publication.
    } finally {
      if (busy == expected) busy = null;
      if (result != null && active()) scheduleNextSample(room, track, result);
    }
    return result;
  }
}
