# Issue 689: Flutter roster on authenticated socket

**Route:** `app/composition` and `features/realtime/dispatch`, bounded integration.

- [x] Adapt app-level behavioral tests for initial unavailable, fresh snapshots, retained expiry, recovery and socket retry without SSE/HTTP polling.
- [x] Negotiate roster capability and bind socket attempt lifecycle and events to the existing roster state.
- [x] Run focused tests/analyzer and a dedicated real-stack scenario on the owned Android emulator.
- [ ] Run full Flutter tests and the registered local-feature gate on the final candidate. Guest maintenance, other native runtimes and load remain separate.
