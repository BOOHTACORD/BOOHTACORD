import 'package:livekit_client/livekit_client.dart' show DisconnectReason;

/// Deliberate room removals must never turn into an automatic rejoin.
bool shouldRecoverVoiceDisconnect(DisconnectReason? reason) => switch (reason) {
  DisconnectReason.serverShutdown ||
  DisconnectReason.stateMismatch ||
  DisconnectReason.joinFailure ||
  DisconnectReason.disconnected ||
  DisconnectReason.signalingConnectionFailure ||
  DisconnectReason.reconnectAttemptsExceeded ||
  DisconnectReason.migration ||
  DisconnectReason.signalClose ||
  DisconnectReason.connectionTimeout ||
  DisconnectReason.mediaFailure => true,
  _ => false,
};
