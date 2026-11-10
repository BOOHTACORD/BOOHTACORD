# Issue 689: process-owned roster coordinator

**Route:** `backend/internal/app/voice_realtime`, lifecycle composition.

- [x] Test hint invalidation and explicit process shutdown, including existing socket stream closure.
- [x] Start one coordinator and bounded authorization pool against injected lister, guard and notifier; unregister hints on shutdown.
- [x] Run repeated/race tests. HTTP route wiring, real stack, write-boundary proof and load remain separate.
