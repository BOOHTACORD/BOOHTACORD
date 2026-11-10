# Issue 689 Flutter Maintenance Event Plan

> **For agentic workers:** Execute this leaf inline; it does not open a new connection or establish runtime acceptance.

**Goal:** Validate maintenance snapshot/change payloads and fail into recovery when a malformed one arrives.

**Architecture:** The existing receive boundary validates the exact schema before delivery. Invalid payloads reset the replay cursor and close/retry through the existing session-scoped lifecycle; valid snapshots stay ephemeral.

**Tech Stack:** Flutter/Dart and flutter_test.

---

### Task: Handle maintenance frames safely

**Files:**
- Create: `clients/flutter/test/realtime_scope/maintenance_event_test.dart`
- Create: `clients/flutter/lib/src/features/realtime/lifecycle/maintenance_payload.dart`
- Modify: `clients/flutter/lib/src/features/realtime/lifecycle/events.dart`
- Modify: `tools/qa/local_features/features.json`
- Modify: `backlog/tasks.yaml`

- [x] Test valid snapshots/changes and reject extra, missing, malformed and unsafe fields with reconnect/full resync rather than silent green state.
- [x] Run `flutter test --no-pub test/realtime_scope/maintenance_event_test.dart` and confirm RED before implementation, including the integer-valued JSON number parity case.
- [x] Implement exact typed validation and fail closed through the existing recovery path; retain durable cursor only for valid durable hints.
- [x] Run focused realtime tests, analyzer, contracts and spec traceability.
- [ ] Complete the Android/other platform and real-stack feature gates; strict validation and recovery for all malformed envelope kinds remain separate work.
