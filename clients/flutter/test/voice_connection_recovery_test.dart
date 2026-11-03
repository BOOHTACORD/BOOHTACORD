import 'package:boohtacord_desktop/src/features/voice/connection_close/recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('transient SDK disconnects may restore the original channel', () {
    for (final reason in [
      DisconnectReason.reconnectAttemptsExceeded,
      DisconnectReason.serverShutdown,
      DisconnectReason.stateMismatch,
      DisconnectReason.disconnected,
      DisconnectReason.signalingConnectionFailure,
      DisconnectReason.signalClose,
      DisconnectReason.connectionTimeout,
      DisconnectReason.mediaFailure,
    ]) {
      expect(shouldRecoverVoiceDisconnect(reason), isTrue, reason: '$reason');
    }
  });

  test('manual leave, administrator removal and identity transfer never auto-rejoin', () {
    for (final reason in [
      DisconnectReason.clientInitiated,
      DisconnectReason.duplicateIdentity,
      DisconnectReason.participantRemoved,
      DisconnectReason.roomDeleted,
      DisconnectReason.roomClosed,
      DisconnectReason.unknown,
    ]) {
      expect(shouldRecoverVoiceDisconnect(reason), isFalse, reason: '$reason');
    }
  });
}
