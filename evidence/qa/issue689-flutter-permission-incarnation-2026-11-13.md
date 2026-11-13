# Issue #689: Flutter permission request incarnation, partial

- Focused tests first reproduced reuse of a permission request predating an
  invalidation and acceptance of a response from a replaced session.
- Strict refresh now starts a new request, ignores older responses and reports
  failure to recovery. Session tickets prevent earlier-session responses from
  being accepted or reused by a subsequent refresh. Old HTTP work is not aborted.
- Four regression tests, ten focused delivery tests, 51 realtime-scope
  tests, the Flutter analyzer and client parity policy passed locally.
- Native Android and iOS runtime, full current-source real-stack, visual review,
  backpressure and production acceptance are NOT_RUN in this record.
