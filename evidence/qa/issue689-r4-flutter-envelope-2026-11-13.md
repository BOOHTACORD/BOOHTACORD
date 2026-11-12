# Issue #689 R4: Flutter new-event envelopes, partial

- Shared Flutter now checks the exact outer envelope, UUID, timestamp and
  optional telemetry of maintenance and roster events. Invalid authenticated
  events clear the replay cursor and trigger socket recovery; the public owner
  marks maintenance unknown. Earlier-event behavior remains unchanged.
- The new regressions reproduced invalid accepted envelopes before the change.
  The 73-test realtime, maintenance and roster-state suite passed, along with
  targeted new roster cases, Flutter analysis and native selection policy tests.
- A native loopback scenario is registered for malformed maintenance recovery;
  its Android execution, full current-source real-stack and visual acceptance,
  iOS, critical event pressure, malformed non-JSON frames and production remain
  NOT_RUN. This record does not claim completion of R4 or issue #689.
