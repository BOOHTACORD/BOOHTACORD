# Issue 689 Maintenance Realtime Contract Plan

> **For agentic workers:** Execute this leaf inline; the new event types are not enabled or broadcast by this packet.

**Goal:** Define typed, versioned maintenance snapshots and changes without accepting internal metadata.

**Architecture:** Extend the existing JSON Schema event envelope with two discriminated branches. A process generation UUID and safe integer revision allow clients to distinguish restarts and ordered states. Unknown status remains a transport/state failure, never `active: false`.

**Tech Stack:** JSON Schema draft 2020-12, Python unittest and jsonschema, PowerShell contract verifier.

---

### Task: Add strict maintenance event payloads

**Files:**
- Create: `tools/verify/realtime_schema/test_maintenance.py`
- Modify: `contracts/realtime.schema.json`
- Modify: `tools/verify/contracts/realtime.ps1`
- Modify: `backlog/tasks.yaml`

- [x] Add positive snapshot/change and negative missing, extra, wrong type, version, generation and revision tests.
- [x] Run `python -m unittest tools.verify.realtime_schema.test_maintenance` and confirm the new positive fixtures fail before schema changes.
- [x] Add both event kinds with the exact `version`, `generation`, `revision`, `active` properties and extend the native structural verifier.
- [x] Run the focused schema tests, the direct contracts verifier and spec traceability. Do not claim clients or transport support until separately implemented and tested.
