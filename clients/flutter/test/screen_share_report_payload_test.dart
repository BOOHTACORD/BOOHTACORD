import 'package:boohtacord_desktop/src/features/screen/metrics/report_payload.dart';
import 'package:boohtacord_desktop/src/features/screen/metrics/sender_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const playing = ScreenShareSenderReport(
    platform: 'android_native',
    state: 'playing',
    frameWidth: 1920,
    frameHeight: 1080,
    encodedFps: 30,
    bitrateKbps: 2400,
  );

  test('reports real monotonic snapshot age with sender measurements', () {
    final report = buildScreenSenderReportPayload(
      report: playing,
      measurementFields: const {
        'stats_source': 'webrtc_interval',
        'collection_state': 'active',
        'target_resolution': 1080,
      },
      sampledAtMs: 1250,
      nowMs: 3475,
    );

    expect(report, {
      'platform': 'android_native',
      'direction': 'sender',
      'state': 'playing',
      'frame_width': 1920,
      'frame_height': 1080,
      'encoded_fps': 30,
      'bitrate_kbps': 2400,
      'stats_source': 'webrtc_interval',
      'collection_state': 'active',
      'target_resolution': 1080,
      'sample_age_ms': 2225,
    });
  });

  test('uses unavailable fallback when no getStats snapshot exists', () {
    final report = buildScreenSenderReportPayload(
      report: playing,
      measurementFields: const {
        'stats_source': 'webrtc_interval',
        'collection_state': 'active',
        'target_resolution': 1080,
        'selected_layer_bitrate_kbps': 2400,
      },
      sampledAtMs: null,
      nowMs: 3475,
    );

    expect(report, {
      'platform': 'android_native',
      'direction': 'sender',
      'state': 'waiting_first_frame',
      'stats_source': 'unsupported',
      'collection_state': 'unavailable',
      'target_resolution': 1080,
    });
    expect(report, isNot(contains('sample_age_ms')));
    expect(report, isNot(contains('encoded_fps')));
    expect(report, isNot(contains('selected_layer_bitrate_kbps')));
  });

  test('sends stale fallback without expired measurements or invalid age', () {
    final report = buildScreenSenderReportPayload(
      report: playing,
      measurementFields: const {
        'stats_source': 'webrtc_interval',
        'collection_state': 'active',
        'target_fps': 60,
        'packet_loss_percent': 0,
      },
      sampledAtMs: 100,
      nowMs: 15101,
    );

    expect(report, {
      'platform': 'android_native',
      'direction': 'sender',
      'state': 'waiting_first_frame',
      'stats_source': 'unsupported',
      'collection_state': 'stale',
      'target_fps': 60,
    });
    expect(report, isNot(contains('sample_age_ms')));
    expect(report, isNot(contains('frame_width')));
    expect(report, isNot(contains('encoded_fps')));
    expect(report, isNot(contains('packet_loss_percent')));
  });
}
