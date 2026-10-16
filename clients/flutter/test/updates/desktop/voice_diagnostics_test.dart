import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/desktop_updates/voice_diagnostics.dart';

void main() {
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
