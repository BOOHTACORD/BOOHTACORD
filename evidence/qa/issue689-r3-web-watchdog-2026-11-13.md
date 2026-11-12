# Issue #689 R3: Web silent-socket recovery, partial

- Before the change, guest and authenticated Web clients rejected the newly
  negotiated heartbeat and did not detect a silent open socket. Focused tests
  reproduced both failures and the missing immediate visibility recheck.
- Web now requests `boohtacord.heartbeat.v1`, accepts only the empty heartbeat
  envelope, keeps it outside feature delivery and replay, and closes a ready
  negotiated socket after 45 seconds without a valid frame. Guest maintenance
  becomes unknown; the existing retry path leaves LiveKit independent.
- A visible-page recheck and browser online notification cover local resume
  signals. Twenty-four focused tests and Vue typecheck passed. Chromium also
  negotiated a real loopback WebSocket whose server stopped sending, observed
  the old connection close, and made a second connection after the deadline.
- Real network blackholes, physical network changes, native clients, production
  and mixed-version rollout/rollback are not established. A client requesting
  this subprotocol requires a compatible server; this is not a rollback proof.
