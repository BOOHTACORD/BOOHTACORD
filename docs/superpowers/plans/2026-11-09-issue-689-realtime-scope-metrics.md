# Issue 689: scoped realtime connection counts

**Route:** public connection lifecycle and fixed-cardinality HTTP metrics.

- [x] Test independent public/authenticated gauges and rejected-upgrade exclusion.
- [x] Wire accepted public sockets into the process recorder and expose only the fixed `scope` label.
- [x] Teach the owned load guard to preserve both fixed scopes without exposing arbitrary labels.
- [x] Verify on a dirty-worktree real-stack smoke that one authenticated socket appears in the authenticated scope and the public scope remains zero.
- [ ] Migrate dashboards and add remaining coordinator/observer queue and latency instrumentation; verify the immutable candidate.
