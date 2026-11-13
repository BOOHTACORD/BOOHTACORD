# Issue #689: Flutter malformed frames, partial

- Authenticated Flutter now closes and recovers when it receives malformed
  JSON, non-object JSON or binary frames. It does not log frame contents.
- Ten focused unit tests, two additional real loopback WebSocket tests and the
  Flutter analyzer passed on the host. The initial unit regression reproduced
  all four missed failures before the changes.
- Native Android/iOS, full current-source real-stack and visual acceptance are
  NOT_RUN. Other in-flight handlers and envelope kinds require separate review.
