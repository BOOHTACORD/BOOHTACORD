import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

import 'dimensions.dart';

/// Reads one current capture snapshot at a publish/update boundary. macOS track
/// settings can contain logical SDK defaults, so only native confirmation is
/// used there. Unknown capture geometry is never replaced with a preview size.
Future<VideoDimensions?> readScreenCaptureDimensions(
  LocalVideoTrack track, {
  required TargetPlatform platform,
  required bool Function() isCurrent,
  Future<Map<String, dynamic>> Function(String)? readSnapshot,
  Duration timeout = const Duration(seconds: 1),
}) async {
  if (!isCurrent()) return null;
  if (platform != TargetPlatform.macOS) {
    return screenShareCaptureDimensions(track);
  }
  final trackId = track.mediaStreamTrack.id;
  if (trackId == null || trackId.isEmpty) return null;
  try {
    final snapshot =
        await (readSnapshot ?? rtc.mediaStreamTrackGetCaptureSnapshot)(trackId)
            .timeout(timeout);
    if (!isCurrent() ||
        snapshot['schema_version'] != 1 ||
        snapshot['status'] != 'active' ||
        snapshot['config_confirmed'] != true) {
      return null;
    }
    final width = snapshot['actual_width'], height = snapshot['actual_height'];
    if (width is! int ||
        height is! int ||
        width < 2 ||
        height < 2 ||
        width > 8192 ||
        height > 8192) {
      return null;
    }
    return VideoDimensions(width, height);
  } catch (_) {
    return null;
  }
}
