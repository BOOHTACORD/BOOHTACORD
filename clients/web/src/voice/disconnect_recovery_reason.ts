// LiveKit's Disconnected event delivers a numeric protocol DisconnectReason.
// A missing reason is the JS SDK's terminal "reconnect policy exhausted" path
// (RTCEngine emits EngineEvent.Disconnected without an argument).
// Never treat a server-directed participant removal, room deletion, duplicate
// identity, or client-initiated exit as a recoverable media outage.
const transientDisconnectReasons = new Set([
  3,  // SERVER_SHUTDOWN
  6,  // STATE_MISMATCH
  7,  // JOIN_FAILURE
  8,  // MIGRATION
  9,  // SIGNAL_CLOSE
  14, // CONNECTION_TIMEOUT
  15, // MEDIA_FAILURE
])

export function shouldRecoverVoiceDisconnect(reason?: number): boolean {
  return reason === undefined || transientDisconnectReasons.has(reason)
}
