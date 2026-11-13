# Issue #689: Web permission request incarnation, partial

- A realtime permission hint could reuse a request started before the hint; its
  older response could then become the displayed permission snapshot. The new
  regression reproduced this missing behavior before the fix.
- Web realtime permission refreshes now invalidate older in-flight responses,
  start a fresh request and report an inconclusive request as an error to the
  realtime recovery path. Account/scope changes still invalidate late results.
  The old HTTP operation itself is not aborted and may continue consuming work.
- Nineteen focused permission/workspace tests, Web typecheck and parity policy passed. Full current-source
  real-stack, visual, Flutter, actual backlog and production acceptance remain
  separate and are NOT_RUN in this record.
