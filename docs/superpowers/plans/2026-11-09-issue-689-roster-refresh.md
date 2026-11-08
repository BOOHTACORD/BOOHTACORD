# Issue 689 per-recipient roster refresh

**Goal:** Let a recipient whose queued snapshot failed current authorization request a fresh full snapshot, even when its visible JSON has not changed.

**Route:** `backend/internal/voice/coordinate_roster` subscription lifecycle.

- [x] Test changed internal lease proof with unchanged public roster and no duplicate fanout to other recipients.
- [x] Confirm RED; discard stale queued state and request one fresh account read for the affected subscriber.
- [x] Run native/race tests; actual guarded socket integration and fault/load gates remain separate.
