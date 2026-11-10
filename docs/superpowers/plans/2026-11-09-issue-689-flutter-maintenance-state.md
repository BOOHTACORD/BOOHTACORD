# Issue 689: Flutter maintenance ownership state

**Route:** `features/session/maintenance_socket`, bounded state leaf.

- [x] Test guest/auth ownership changes, initial unknown state, stale generations/revisions and disconnect without inventing inactive maintenance.
- [x] Implement a socket-independent versioned maintenance state with explicit ownership tokens.
- [x] Run focused Dart tests/analyzer. Guest transport, app handoff, native UI/runtime and load remain separate.
