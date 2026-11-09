# Issue 689 Flutter voice roster contract

**Goal:** Validate typed roster snapshots and safe unavailable events on the common Flutter realtime owner without advancing durable replay cursors.

**Route:** `clients/flutter/lib/src/features/realtime/lifecycle`, with nearest behavior tests.

- [x] Test valid/empty roster, unavailable, cursor and malformed data recovery.
- [x] Confirm RED; add strict versioned payload validation matching the schema and Web behavior.
- [x] Run Flutter focused tests/analyze and register the scenario; real Android delivery and native parity remain separate.
