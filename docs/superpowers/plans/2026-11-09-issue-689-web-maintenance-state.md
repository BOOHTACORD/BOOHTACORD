# Issue 689 Web maintenance state ownership

**Goal:** Apply versioned maintenance events without allowing stale sockets, revisions or previous server generations to overwrite current state.

**Route:** `clients/web/src/maintenance`, a feature-state leaf; transport ownership and UI handoff follow separately.

- [x] Test connection generations, snapshot-before-change, monotone revisions, reconnect, unavailable state and malformed payloads.
- [x] Verify RED, implement a small state owner that preserves last known active state on disconnect.
- [x] Run focused Web tests and record that UI/real-stack acceptance remains pending.
