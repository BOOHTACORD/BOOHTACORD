import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/qa98325_receiver_observer.dart';

Map<String, Object?> fixture() => {
  'schema_version': 1,
  'scope': {
    'origin_id': 'https://voice.example.test',
    'account_id': 'private-account',
    'room_id': 'private-room',
    'media_session_id': 'private-session',
    'publication_generation': 4,
    'operation_revision': 12,
  },
  'mode': 'motion',
  'publisher_state': 'sharing',
  'viewer_state': 'idle',
  'requested_profile_id': 'P1080_60',
  'effective_profile': {
    'capture': {'max_width': 1920, 'max_height': 1080, 'max_fps': 60},
    'encoding': {
      'codec': 'VP8',
      'layers': [
        {
          'rid': 'private-rid',
          'width': 1920,
          'height': 1080,
          'max_fps': 60,
          'max_bitrate_bps': 8000000,
          'scale_down_by': 1,
          'active': true,
        },
      ],
    },
  },
  'layer_topology': 'single-layer',
  'profile_revision': 1,
  'capabilities': {
    'live_update': true,
    'republish_without_recapture': false,
    'simulcast': false,
  },
  'reason_codes': ['user-request'],
};
Map<String, Object?> observe(
  String? raw, {
  String? origin = 'https://voice.example.test',
  String? account = 'private-account',
  String? room = 'private-room',
  bool publication = true,
}) => qaReceiverDescriptorProjection(
  raw,
  expectedOrigin: origin,
  expectedAccountId: account,
  expectedRoomId: room,
  publicationPresent: publication,
  trackPresent: publication,
  subscribed: publication,
);
void main() {
  test('actual reader projection uses production scoped parser and safe config only', () {
    final value = observe(jsonEncode(fixture()));
    expect(value['descriptor_valid'], true);
    expect(value['scope_verified'], true);
    expect(value['remote_subscribed'], true);
    expect(value['requested_profile_id'], 'P1080_60');
    expect(value['publication_generation'], 4);
    expect(value['operation_revision'], 12);
    expect(value.toString(), isNot(contains('private')));
    expect(value['sender_metrics_proven'], false);
    expect(value['remote_capture_age'], 'unknown');
  });
  test('missing scope rejects even otherwise valid descriptor', () {
    for (final value in [
      observe(jsonEncode(fixture()), origin: null),
      observe(jsonEncode(fixture()), account: null),
      observe(jsonEncode(fixture()), room: null),
    ]) {
      expect(value['descriptor_valid'], false);
      expect(value['scope_verified'], false);
      expect(value.containsKey('effective_profile'), false);
    }
  });
  test('foreign scopes fail without exposing account or room', () {
    for (final value in [
      observe(jsonEncode(fixture()), origin: 'https://other.example.test'),
      observe(jsonEncode(fixture()), account: 'other'),
      observe(jsonEncode(fixture()), room: 'other'),
    ]) {
      expect(value['descriptor_valid'], false);
      expect(value.toString(), isNot(contains('private')));
    }
  });
  test('absent malformed and oversized remote attrs remain unknown', () {
    for (final raw in [null, '{invalid', 'a' * 4097]) {
      final value = observe(raw);
      expect(value['descriptor_valid'], false);
      expect(value.containsKey('effective_profile'), false);
      if (raw != null && raw.length > 4096) {
        expect(value['descriptor_payload_sha256'], null);
      }
    }
  });
  test('metadata alone does not prove track or publication binding', () {
    final value = observe(jsonEncode(fixture()), publication: false);
    expect(value['descriptor_valid'], true);
    expect(value['remote_publication_present'], false);
    expect(value['remote_track_present'], false);
    expect(value['remote_subscribed'], false);
    expect(value['publication_binding'], 'v1_schema_has_no_publication_sid');
  });
  test('text and explicit requested rate remain independent', () {
    final data = fixture();
    data['mode'] = 'text';
    data['requested_profile_id'] = 'P1080_30';
    final value = observe(jsonEncode(data));
    expect(value['mode'], 'text');
    expect(value['requested_profile_id'], 'P1080_30');
    expect(value['descriptor_valid'], true);
  });
}
