import 'package:boohtacord_desktop/src/features/screen/metrics/sender_report.dart';
import 'package:boohtacord_desktop/src/features/screen/metrics/telemetry_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scope = ScreenTelemetryPublicationScope(
    ownerLeaseId: '11111111-1111-4111-8111-111111111111',
    mediaSessionId: 'media-session-1',
    publicationGeneration: 4,
    captureWidth: 1920,
    captureHeight: 1080,
    captureFps: 30,
  );

  test(
    'maps native sender metrics with fixed platform and explicit provenance',
    () {
      final envelope = buildFlutterScreenTelemetryEnvelope(
        scope: scope,
        platform: 'android',
        report: const ScreenShareSenderReport(
          platform: 'android_native',
          state: 'playing',
          frameWidth: 1280,
          frameHeight: 720,
          encodedFps: 24,
          bitrateKbps: 1400,
          roundTripTimeMs: 40,
        ),
        measurementFields: const {
          'packet_loss_percent': 2.0,
          'packet_loss_window_ms': 10000.0,
          'adaptation_reason': 'cpu',
        },
        sequence: 7,
        sampledAtMonotonicMs: 95000,
        nowMonotonicMs: 100000,
      );

      expect(envelope, {
        'schema_version': 1,
        'media_session_id': 'media-session-1',
        'publication_generation': 4,
        'platform': 'android',
        'client_kind': 'flutter',
        'capability_version': 1,
        'sequence': 7,
        'sender_sample_age_ms': 5000,
        'capture': {
          'width': {
            'value': 1920,
            'availability': 'measured',
            'provenance': 'sender_measured',
          },
          'height': {
            'value': 1080,
            'availability': 'measured',
            'provenance': 'sender_measured',
          },
          'fps': {
            'value': 30,
            'availability': 'configured_only',
            'provenance': 'configured',
          },
        },
        'encode': {
          'fps': {
            'value': 24.0,
            'availability': 'measured',
            'provenance': 'sender_measured',
          },
          'bitrate_bps': {
            'value': 1400000.0,
            'availability': 'measured',
            'provenance': 'sender_measured',
          },
        },
        'transport': {
          'packet_loss_percent': {
            'value': 2.0,
            'availability': 'measured',
            'provenance': 'sender_measured',
          },
          'rtt_ms': {
            'value': 40.0,
            'availability': 'measured',
            'provenance': 'sender_measured',
          },
          'quality_limitation_reason': {
            'value': 'cpu',
            'availability': 'measured',
            'provenance': 'sender_measured',
          },
        },
      });
    },
  );

  test('marks stats unsupported or stale without substituting values', () {
    final unsupported = buildFlutterScreenTelemetryEnvelope(
      scope: const ScreenTelemetryPublicationScope(
        ownerLeaseId: '11111111-1111-4111-8111-111111111111',
        mediaSessionId: 'media-session-1',
        publicationGeneration: 4,
      ),
      platform: 'ios',
      report: const ScreenShareSenderReport(
        platform: 'ios_native',
        state: 'waiting_first_frame',
      ),
      measurementFields: const {'stats_source': 'unsupported'},
      sequence: 1,
      sampledAtMonotonicMs: null,
      nowMonotonicMs: 1000,
    );
    expect(unsupported['sender_sample_age_ms'], isNull);
    expect((unsupported['encode'] as Map)['fps'], {
      'availability': 'unsupported',
      'provenance': 'unavailable',
    });
    expect((unsupported['transport'] as Map)['rtt_ms'], {
      'availability': 'unsupported',
      'provenance': 'unavailable',
    });
    expect((unsupported['capture'] as Map)['fps'], {
      'availability': 'not_exposed',
      'provenance': 'unavailable',
    });

    final stale = buildFlutterScreenTelemetryEnvelope(
      scope: scope,
      platform: 'windows',
      report: const ScreenShareSenderReport(
        platform: 'windows_native',
        state: 'playing',
        encodedFps: 22,
      ),
      measurementFields: const {},
      sequence: 2,
      sampledAtMonotonicMs: 1000,
      nowMonotonicMs: 20000,
    );
    expect(stale['sender_sample_age_ms'], 19000);
    expect((stale['encode'] as Map)['fps'], {
      'availability': 'stale',
      'provenance': 'unavailable',
    });
  });
}
