import 'dart:collection';

import 'package:boohtacord_desktop/src/services/screen_share_diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('track diagnostics tolerate tracks without native media state', () {
    final track = _TrackWithoutNativeState();
    expect(screenShareTrackEnabled(track), isNull);
  });

  test('publication diagnostics tolerate incomplete fake room state', () {
    final room = _RoomWithoutPublicationState();
    expect(screenShareLocalPublicationCount(room), isNull);
    expect(screenShareRemoteCounts(room), isNull);
  });

  test('formats bounded publication lifecycle diagnostics', () {
    expect(
      formatScreenShareDiagnosticLine(
        ScreenShareDiagnosticEvent.publishCompleted,
        platform: TargetPlatform.android,
        trackEnabled: true,
        localScreenPublications: 1,
      ),
      '[screen-share] event=publish_completed platform=android '
      'track_enabled=true local_screen_publications=1',
    );
  });

  test('does not include arbitrary error text or high-cardinality values', () {
    final line = formatScreenShareDiagnosticLine(
      ScreenShareDiagnosticEvent.publishFailed,
      platform: TargetPlatform.macOS,
      errorType: 'TrackPublishException(user=alice, track=abc123)',
      remoteScreenPublications: -1,
    );

    expect(line, '[screen-share] event=publish_failed platform=macOS');
    expect(line, isNot(contains('alice')));
    expect(line, isNot(contains('abc123')));
  });

  test('logs only low-cardinality, content-free measurements', () {
    final original = debugPrint;
    final lines = <String?>[];
    debugPrint = (message, {wrapWidth}) => lines.add(message);
    addTearDown(() => debugPrint = original);

    logScreenShareDiagnostic(
      ScreenShareDiagnosticEvent.senderStatsSampled,
      platform: TargetPlatform.android,
      senderStatsEntries: 1,
      framesSent: 120,
      bytesSent: 900000,
      encodedFramesPerSecond: 15,
    );

    expect(lines, [
      '[screen-share] event=sender_stats_sampled platform=android '
          'sender_stats_entries=1 frames_sent=120 bytes_sent=900000 '
          'encoded_fps=15',
    ]);
  });

  test(
    'classifies sender export failures without exposing request details',
    () {
      expect(
        formatScreenShareDiagnosticLine(
          ScreenShareDiagnosticEvent.senderReportFailed,
          platform: TargetPlatform.android,
          durationMs: 55.4,
          errorClass: 'http_5xx',
          httpStatusClass: '5xx',
          errorType: 'ApiFailure(private body and lease)',
        ),
        '[screen-share] event=sender_report_failed platform=android '
        'duration_ms=55 error_class=http_5xx http_status_class=5xx',
      );
    },
  );
}

class _TrackWithoutNativeState implements LocalTrack {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RoomWithoutPublicationState implements Room {
  @override
  LocalParticipant get localParticipant => _ParticipantWithoutPublications();

  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView({'test': _RemoteParticipantWithoutPublications()});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ParticipantWithoutPublications implements LocalParticipant {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RemoteParticipantWithoutPublications implements RemoteParticipant {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
