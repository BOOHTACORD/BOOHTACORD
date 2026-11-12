# Issue #689 R2: Web connection deadlines, partial

- Base: R1 checkpoint `33490c5579e6a750dbc586c87b0012ae0e2fc517`.
- An authenticated Web socket that never opened or opened without a ready
  frame failed the new fake-timer regressions before the change. An unfinished
  session check also prevented retry; tests now cover its deadline and abort.
- The Web attempt is closed after 15 seconds without `connection.ready` and
  uses the existing bounded reconnect schedule. Session revalidation has a
  10-second bound; timeout or explicit reconnect/disconnect aborts the request.
  A timeout is treated as unknown, not proof of an expired session.
- Focused Web checks: ten tests passed, including session AbortSignal
  propagation and stale session-result guards. This is source-level evidence.
- Real HTTP upgrade with an accepted but unanswered handshake, complete Web
  real-stack/visual review and Flutter/native implementation and tests are
  NOT_RUN. These results do not close R2 or establish production behavior.
