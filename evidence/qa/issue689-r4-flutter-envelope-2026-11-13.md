# Issue #689 R4: Flutter new-event envelopes, partial

- Shared Flutter now checks the exact outer envelope, UUID, timestamp and
  optional telemetry of maintenance and roster events. Invalid authenticated
  events clear the replay cursor and trigger socket recovery; the public owner
  marks maintenance unknown. Earlier-event behavior remains unchanged.
- The new regressions reproduced invalid accepted envelopes before the change.
  The 73-test realtime, maintenance and roster-state suite passed, along with
  targeted new roster cases, Flutter analysis and native selection policy tests.
- Android API 35 x86_64 emulator `emulator-5560` ran the native loopback test
  successfully at source `f67eb83e5bd52bfc25c42cd00af9ae56949877a1`. The debug
  APK SHA-256 was `95e2cb731334540332cee779357c431d2d5e4888d2e390ee6fce6eaf1ec35cdc`.
  This was not a release build or a test of a real backend.
- Full current-source real-stack and visual acceptance, iOS, critical event
  pressure, malformed non-JSON frames and production remain NOT_RUN. This record
  does not claim completion of R4 or issue #689.
