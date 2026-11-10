# Issue 689: Flutter shared-socket roster state

**Route:** `features/voice/roster_state`, one lifecycle leaf.

- [x] Test opt-in shared socket state, initial timeout, stale retention, revision ordering, retry and session-scope cleanup with no SSE/HTTP roster request.
- [x] Add the shared mode without changing existing production wiring; parse only validated roster envelopes and preserve existing UI phase semantics.
- [x] Run focused Flutter tests and analyze. App composition, Android runtime, other platforms and load remain separate.
