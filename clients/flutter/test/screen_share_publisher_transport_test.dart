import 'dart:convert';

import 'package:boohtacord_desktop/src/features/screen/metrics/livekit_layers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

rtc.StatsReport row(String id, String type, Map<String, dynamic> values) =>
    rtc.StatsReport(id, type, 1000000, values);
List<rtc.StatsReport> fixture() => [
  row('out', 'outbound-rtp', {
    'kind': 'video',
    'transportId': 'transport-owned',
    'framesEncoded': 10,
  }),
  row('foreign-pair', 'candidate-pair', {
    'state': 'succeeded',
    'localCandidateId': 'foreign-local',
    'remoteCandidateId': 'foreign-remote',
    'currentRoundTripTime': .9,
  }),
  row('transport-owned', 'transport', {'selectedCandidatePairId': 'selected'}),
  row('selected', 'candidate-pair', {
    'state': 'succeeded',
    'localCandidateId': 'local',
    'remoteCandidateId': 'remote',
    'currentRoundTripTime': .01,
    'availableOutgoingBitrate': 8000000,
    'availableIncomingBitrate': 300000,
  }),
  row('local', 'local-candidate', {
    'protocol': 'tcp',
    'candidateType': 'relay',
    'relayProtocol': 'tls',
    'address': '192.0.2.9',
    'port': 56789,
    'usernameFragment': 'private-fragment',
  }),
  row('remote', 'remote-candidate', {
    'protocol': 'tcp',
    'candidateType': 'host',
    'address': '198.51.100.5',
    'port': 12345,
  }),
  row('foreign-local', 'local-candidate', {
    'protocol': 'udp',
    'candidateType': 'host',
    'address': '203.0.113.25',
  }),
  row('foreign-remote', 'remote-candidate', {
    'protocol': 'udp',
    'candidateType': 'host',
  }),
];
void main() {
  test(
    'publisher transport follows selectedlink ratherthan firstcandidate pair',
    () {
      final transport = screenSenderSourcesFromReports(fixture())
          .single
          .counters
          .transport!;
      expect(transport.candidateProtocol, 'tcp');
      expect(transport.localCandidateType, 'relay');
      expect(transport.remoteCandidateType, 'host');
      expect(transport.relayProtocol, 'tls');
      expect(transport.roundTripTimeSeconds, .01);
      expect(transport.availableOutgoingBitrate, 8000000);
      final public = jsonEncode(transport.toPublicJson());
      for (final forbidden in [
        '192.0.2',
        '198.51.100',
        '203.0.113',
        'private',
        '56789',
        'selected',
        'transport-owned',
      ]) {
        expect(public, isNot(contains(forbidden)));
      }
    },
  );
  test('missing links or non-succeededselectedpair remain unknown', () {
    for (final omitted in ['transport-owned', 'selected', 'local', 'remote']) {
      expect(
        screenSenderSourcesFromReports(
          fixture().where((r) => r.id != omitted).toList(),
        ).single.counters.transport,
        isNull,
      );
    }
    final reports = fixture();
    reports[3] = row('selected', 'candidate-pair', {
      'state': 'in-progress',
      'localCandidateId': 'local',
      'remoteCandidateId': 'remote',
    });
    expect(
      screenSenderSourcesFromReports(reports).single.counters.transport,
      isNull,
    );
  });
  test(
    'unavailable or invalid estimates do not become zero or healthybandwidth',
    () {
      final reports = fixture();
      reports[3] = row('selected', 'candidate-pair', {
        'state': 'succeeded',
        'localCandidateId': 'local',
        'remoteCandidateId': 'remote',
        'currentRoundTripTime': -1,
        'availableOutgoingBitrate': double.nan,
      });
      final transport = screenSenderSourcesFromReports(reports)
          .single
          .counters
          .transport!;
      expect(transport.roundTripTimeSeconds, isNull);
      expect(transport.availableOutgoingBitrate, isNull);
      expect(transport.availableIncomingBitrate, isNull);
      expect(
        transport.toPublicJson()['bandwidth_provenance'],
        'candidate_pair_estimate_not_SFU_truth',
      );
    },
  );
}
