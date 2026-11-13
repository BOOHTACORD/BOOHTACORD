# Issue #689 R4: server overflow security hints, partial

- A synthetic 64-entry server queue reproduced loss of session and permission
  hints after overflow. Targeted, transient and broadcast paths previously did
  not retain all these classes while a subscriber was marked dropped.
- The bounded critical buffer now retains session, permission and voice revoke
  events with capability and recipient filtering. If a transient security hint
  cannot fit, overflow acknowledgement requires a WebSocket close instead of
  claiming successful recovery. Durable voice revokes keep their retry path.
- Focused Go tests exercise queued and later hints, 64-entry overflow, private
  routing, capability checks and saturated retention. A loopback WebSocket test
  observed a 1013 close after saturation. The change does not establish real
  slow-reader load, client-side 256-entry pressure or full cross-client resync.
- Full current-source real-stack, release, security and production acceptance
  remain NOT_RUN. This record does not close R4 or issue #689.
