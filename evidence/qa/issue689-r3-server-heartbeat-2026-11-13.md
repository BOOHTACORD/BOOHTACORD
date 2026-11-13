# Issue #689 R3: negotiated server heartbeat, partial

- New public and authenticated sockets may negotiate the fixed WebSocket
  subprotocol `boohtacord.heartbeat.v1`; legacy sockets receive no new frames.
- The server sends an empty, non-replayable `connection.heartbeat` about every
  15 seconds only when that subprotocol was selected. The public endpoint still
  rejects query parameters and the existing Origin and quota rules apply.
- Real loopback WebSocket tests passed for both endpoint types, including 16
  seconds without heartbeat on legacy connections. Go package tests, focused
  Linux race tests, `go vet`, schema validation and the native contracts
  verifier passed locally.
- Client watchdogs, network blackholes, background/resume, mixed-version
  cutover/rollback, Android/iOS and production behaviour remain NOT_RUN.
  This server-only change cannot by itself close R3.
