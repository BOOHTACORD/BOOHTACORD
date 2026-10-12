import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Low-cardinality, content-free milestones for diagnosing share publication.
enum ScreenShareDiagnosticEvent {
  captureRequested('capture_requested'),
  capturePrepared('capture_prepared'),
  captureCreated('capture_created'),
  captureFailed('capture_failed'),
  publishStarted('publish_started'),
  publishCompleted('publish_completed'),
  publishFailed('publish_failed'),
  localPublished('local_published'),
  localUnpublished('local_unpublished'),
  remoteParticipantConnected('remote_participant_connected'),
  remoteParticipantDisconnected('remote_participant_disconnected'),
  remoteTrackPublished('remote_track_published'),
  remoteTrackSubscribed('remote_track_subscribed'),
  remoteTrackUnsubscribed('remote_track_unsubscribed'),
  remoteTrackUnpublished('remote_track_unpublished'),
  senderStatsSampled('sender_stats_sampled'),
  senderStatsUnavailable('sender_stats_unavailable'),
  senderReportStarted('sender_report_started'),
  senderReportSent('sender_report_sent'),
  senderReportFailed('sender_report_failed');

  const ScreenShareDiagnosticEvent(this.value);

  final String value;
}

/// Returns `null` when a platform/fake track cannot expose its native state.
/// Diagnostics must never interrupt capture or publication lifecycles.
bool? screenShareTrackEnabled(LocalTrack? track) {
  try {
    return track?.mediaStreamTrack.enabled;
  } catch (_) {
    return null;
  }
}

int? screenShareLocalPublicationCount(Room room) {
  try {
    return room.localParticipant?.videoTrackPublications
            .where(
              (publication) =>
                  publication.source == TrackSource.screenShareVideo,
            )
            .length ??
        0;
  } catch (_) {
    return null;
  }
}

({int participants, int publications})? screenShareRemoteCounts(Room room) {
  try {
    final participants = room.remoteParticipants;
    return (
      participants: participants.length,
      publications: participants.values.fold<int>(
        0,
        (count, participant) =>
            count +
            participant.videoTrackPublications
                .where(
                  (publication) =>
                      publication.source == TrackSource.screenShareVideo,
                )
                .length,
      ),
    );
  } catch (_) {
    return null;
  }
}

/// Formats only fixed event names, platform, booleans, numeric counters and a
/// simple exception type. Do not add identities, track IDs, room IDs or text.
@visibleForTesting
String formatScreenShareDiagnosticLine(
  ScreenShareDiagnosticEvent event, {
  required TargetPlatform platform,
  bool? trackEnabled,
  int? localScreenPublications,
  int? remoteScreenPublications,
  int? remoteParticipants,
  int? senderStatsEntries,
  int? framesSent,
  int? bytesSent,
  int? encodedFramesPerSecond,
  double? durationMs,
  String? errorClass,
  String? httpStatusClass,
  String? errorType,
}) {
  final fields = <String>[
    '[screen-share]',
    'event=${event.value}',
    'platform=${platform.name}',
  ];
  void addCounter(String name, int? value) {
    if (value != null && value >= 0) fields.add('$name=$value');
  }

  if (trackEnabled != null) fields.add('track_enabled=$trackEnabled');
  addCounter('local_screen_publications', localScreenPublications);
  addCounter('remote_screen_publications', remoteScreenPublications);
  addCounter('remote_participants', remoteParticipants);
  addCounter('sender_stats_entries', senderStatsEntries);
  addCounter('frames_sent', framesSent);
  addCounter('bytes_sent', bytesSent);
  addCounter('encoded_fps', encodedFramesPerSecond);
  if (durationMs != null && durationMs.isFinite && durationMs >= 0) {
    fields.add('duration_ms=${durationMs.round()}');
  }
  if (errorClass != null &&
      const {
        'http_timeout',
        'http_4xx',
        'http_5xx',
        'network',
        'session_invalidated',
      }.contains(errorClass)) {
    fields.add('error_class=$errorClass');
  }
  if (const {'4xx', '5xx', 'other'}.contains(httpStatusClass)) {
    fields.add('http_status_class=$httpStatusClass');
  }
  if (errorType != null &&
      RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,47}$').hasMatch(errorType)) {
    fields.add('error_type=$errorType');
  }
  return fields.join(' ');
}

void logScreenShareDiagnostic(
  ScreenShareDiagnosticEvent event, {
  required TargetPlatform platform,
  bool? trackEnabled,
  int? localScreenPublications,
  int? remoteScreenPublications,
  int? remoteParticipants,
  int? senderStatsEntries,
  int? framesSent,
  int? bytesSent,
  int? encodedFramesPerSecond,
  double? durationMs,
  String? errorClass,
  String? httpStatusClass,
  String? errorType,
}) {
  debugPrint(
    formatScreenShareDiagnosticLine(
      event,
      platform: platform,
      trackEnabled: trackEnabled,
      localScreenPublications: localScreenPublications,
      remoteScreenPublications: remoteScreenPublications,
      remoteParticipants: remoteParticipants,
      senderStatsEntries: senderStatsEntries,
      framesSent: framesSent,
      bytesSent: bytesSent,
      encodedFramesPerSecond: encodedFramesPerSecond,
      durationMs: durationMs,
      errorClass: errorClass,
      httpStatusClass: httpStatusClass,
      errorType: errorType,
    ),
  );
}
