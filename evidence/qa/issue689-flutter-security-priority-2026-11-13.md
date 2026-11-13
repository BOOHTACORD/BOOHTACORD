# Issue #689: Flutter security hint priority, partial

- A regression test reproduced delayed session and permission hints behind a
  blocked ordinary event, including a near-full synthetic backlog.
- Session and permission hints use independent bounded lanes. Permission hints
  are serialized with one coalesced follow-up. A failure resets delivery and
  requires recovery; reset fences queued callbacks from an earlier epoch.
- Nineteen focused delivery and permission tests, 56 realtime-scope tests,
  Flutter analyzer, client parity and signal catalog checks passed.
- A callback already running at disconnect is not cancelled by this delivery
  layer; its own state owner must fence late effects. Native devices, an actual
  slow network reader, full current-source real-stack and visual review remain
  NOT_RUN. This record does not establish production load behavior.
