# Issue 689: retire the Flutter roster stream state machine

**Route:** `clients/flutter/lib/src/features/voice/roster_state`.

- [x] Preserve stale expiration, invalid snapshot handling, retry and late-event fences in shared-socket tests.
- [x] Remove the legacy stream watcher, polling refresh, private retry state and feature flag.
- [x] Migrate applicable state tests and verify shared-session expiration and socket ownership.
- [x] Run targeted Flutter tests and analyzer; full runtime, platform and feature acceptance remain separate.
- [ ] Remove remaining unreachable stream API facades and migrate their test fixtures.
