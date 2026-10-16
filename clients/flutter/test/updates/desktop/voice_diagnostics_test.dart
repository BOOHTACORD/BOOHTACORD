import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../../../integration_test/desktop_updates/voice_diagnostics.dart';

void main() {
  test('ICE observation retains counts and enums without addresses or IDs', () {
    final observation = AcceptanceVoiceDiagnostics();
    observation.observeStats([
      [
        rtc.StatsReport('SECRET-ID', 'local-candidate', 0, {
          'address': '10.23.45.67',
          'protocol': 'udp',
          'candidateType': 'host',
          'usernameFragment': 'SECRET',
        }),
        rtc.StatsReport('PRIVATE-ID', 'remote-candidate', 0, {
          'address': '127.0.0.1',
          'protocol': 'tcp',
          'candidateType': 'host',
        }),
        rtc.StatsReport('PAIR-ID', 'candidate-pair', 0, {
          'state': 'in-progress',
          'nominated': false,
          'requestsSent': 8,
          'responsesReceived': 0,
          'remoteCandidateId': 'PRIVATE-ID',
        }),
      ],
    ]);
    observation.observeStats([[]]);
    final report = observation.ice;
    expect(report['samples'], 2);
    expect(report['local_candidates_max'], 1);
    expect(report['remote_candidates_max'], 1);
    expect(report['remote_loopback_seen'], true);
    expect(report['local_nonloopback_seen'], true);
    expect(report['pair_states'], ['in-progress']);
    expect(report['pair_request_seen'], true);
    expect(report['pair_response_seen'], false);
    expect(report['protocols'], ['tcp', 'udp']);
    final encoded = jsonEncode(report);
    for (final private in [
      'SECRET',
      'PRIVATE',
      'PAIR-ID',
      '10.23.45.67',
      '127.0.0.1',
    ]) {
      expect(encoded.contains(private), isFalse);
    }
  });

  test('keeps only bounded connection categories, never log content', () {
    final observation = AcceptanceVoiceDiagnostics();
    observation.observe(
      'livekit',
      'could not connect to wss://private.invalid?token=SECRET '
          'LiveKit Exception: [MediaConnectException] private data',
    );
    observation.observe('livekit', 'received websocket error PRIVATE');
    observation.observe('livekit', 'unrelated message body SECRET');
    observation.observe('untrusted-logger', '[NegotiationError] PRIVATE');
    observation.observe('livekit', '[MediaConnectException] duplicate');
    expect(observation.codes, ['ice_connect', 'signaling_socket']);
    final encoded = jsonEncode(observation.codes);
    for (final private in ['SECRET', 'PRIVATE', 'private.invalid', 'token']) {
      expect(encoded.contains(private), isFalse);
    }
  });

  test(
    'classifies original SDK failure without echoing exceptions or URLs',
    () {
      final cases = {
        '[ConnectException] Timed out waiting for SignalJoinResponseEvent':
            'signaling_timeout',
        '[ConnectException] no internet connection': 'offline',
        '[NegotiationError] arbitrary SDP': 'negotiation',
        '[CertificatePinningException] secret host': 'tls',
        'could not connect to SECRET HandshakeException': 'tls',
        'could not connect to SECRET unknown failure': 'unclassified',
      };
      for (final entry in cases.entries) {
        final observation = AcceptanceVoiceDiagnostics();
        observation.observe('livekit', entry.key);
        expect(observation.codes, [entry.value]);
      }
    },
  );
}
