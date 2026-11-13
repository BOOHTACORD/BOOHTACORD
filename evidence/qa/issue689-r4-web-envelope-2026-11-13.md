# Issue #689 R4: Web new-event envelopes, partial

- Before the change, Web accepted maintenance and roster events with malformed
  event identifiers, extra outer properties or invalid optional telemetry. A
  malformed event could leave the socket open without requesting recovery.
- Web now checks the outer envelope of those four event kinds against the shared
  contract and reconnects after an invalid new event. The guest owner marks
  maintenance unknown. Legacy event-kind error handling remains unchanged.
- Ninety Web realtime/maintenance tests and Vue typecheck passed. Chromium
  received a malformed maintenance envelope from a loopback WebSocket and opened
  a replacement connection. Client parity and signal-catalog generation passed.
- Flutter envelope validation, malformed non-JSON frames, all critical classes
  under backlog and slow-reader pressure, full real-stack/visual acceptance and
  production behavior remain NOT_RUN for this change. This evidence is partial.
