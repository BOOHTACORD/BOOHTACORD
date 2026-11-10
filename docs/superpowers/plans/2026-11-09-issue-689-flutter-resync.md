# Issue 689 Flutter Resync Envelope Plan

> **For agentic workers:** Execute this focused leaf inline; native and real-stack acceptance remain separate gates.

**Goal:** Accept the existing typed server resync envelope so the Flutter client clears its replay cursor and recovers.

**Architecture:** Validate the control payload at the existing receive boundary. Preserve empty `connection.ready` validation, the existing delivery queue, recovery and session-generation guards.

**Tech Stack:** Flutter/Dart, flutter_test, existing realtime delivery.

---

### Task: Validate incoming resync reasons

**Files:**
- Create: `clients/flutter/test/realtime_scope/resync_envelope_test.dart`
- Create: `clients/flutter/lib/src/features/realtime/lifecycle/resync_payload.dart`
- Modify: `clients/flutter/lib/src/features/realtime/lifecycle/events.dart`
- Modify: `tools/qa/local_features/features.json`
- Modify: `backlog/tasks.yaml`

- [x] Test that a valid server reason clears an existing cursor and invokes recovery; missing, unknown or extra fields must not do so.
- [x] Run the focused Flutter test and confirm RED against the current receive boundary.
- [x] Permit exactly the six reasons in `contracts/realtime.schema.json`, leaving the ready payload empty-only.
- [ ] Complete `tools/qa/local_features/check.sh --feature connection_status --base <base-ref> --real-stack` with the Android runtime and inspect its images. Focused tests and traceability passed; the initial native attempt failed before app startup and visual retry was interrupted, as recorded in evidence.
