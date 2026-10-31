# Five critical remaining software issues — implementation plan

> Execute inline, one capability and native verification packet at a time.

**Goal:** Implement #89, #56, #80, #79 and #64 with reproducible acceptance.
**Architecture:** Preserve Go/Vue/ACL/secure-cookie/LiveKit contracts. Guard the
attachment volume with an OS process lock; test reservation through an isolated
capacity-limited API. Coalesce protected refreshes while preserving durable replay
and immediate revocation. Expose independent chat/voice/roster status and accurate
registration/login outcomes.
**Tech stack:** Go 1.26.4, Vue 3, TypeScript/Vitest, Playwright, PostgreSQL 17.6.

## Operating brief

Class `split_first`, followed by separate leaf implementation/review packets.
Roots: native manifests and exact edges, no aggregate source search. Ratchet:
100 target/120 hard lines, 8 target/16 hard production files and direct tests.
Preserve password bytes, account/session scope, ID-only hints, history pagination,
notification privacy, current media ownership and reservation thresholds.
P0 Android #47/#48/#49/#86 already contain code and require unavailable physical
device acceptance; no duplicate implementation or false gate closure.
Stop after all five source changes, relevant actual scenarios, native checks and
CI pass; preserve any original production/device criterion not executed.

## #89 — one attachment writer

Files: `backend/internal/storage/acquire_writer_lock/{lock.go,lock_unix.go,
lock_windows.go,lock_test.go}`, `backend/internal/app/runtime/run.go`,
`docs/runbooks/attachment-writer.md`, `deploy/compose.yaml`.

- [x] First regression: acquire directory, reject second holder, release then
  reacquire; independent-process tests verify crash release and handover.
  `second, err := Acquire(root); if err == nil { second.Close(); t.Fatal("second writer") }`
- [x] Implement nonblocking OS lock on a persistent private lock file; never
  unlink its inode. Acquire before API workers and release after shutdown.
  `resources.Add(func(context.Context) error { return writer.Close() })`
- [x] Declare one Compose replica and document stop/start rollout/rollback.
- [x] Run `go test ./internal/storage/acquire_writer_lock ./internal/app/runtime`.

## #64 — registration and login outcomes

Files: `clients/web/src/identity/authentication_flow/{flow.ts,flow.spec.ts,
retry_after.ts,retry_after.spec.ts}`, `auth_client.ts`, `AuthenticationLanding.vue`.

- [x] Test successful registration followed by failed login, 429 delta/date,
  explicit manual retry, unchanged Unicode password and no duplicate register.
  `expect(register).toHaveBeenCalledOnce(); expect(flow.registered.value).toBe(true)`
- [x] Implement reusable flow state, safe error copy and Retry-After feedback;
  after register success switch subsequent submission to login only.
  `if (!registered.value) await register(input); await login(input)`
- [x] Preserve recovery explanation, show-password accessibility and reset focus.
- [x] Run focused Vitest identity tests and actual browser auth journey.

## #79 — independent connection status

Files: `clients/web/src/workspace/connection_status/{model.ts,model.spec.ts,
Status.vue}`, `WorkspaceApp.vue`, `voice/voice_roster_realtime.ts` and its tests.

- [x] Test WS-only failure with connected media, stale roster age, retry and
  unavailable roster distinct from a successful empty snapshot.
  `expect(status.voice).toBe('Голос подключён'); expect(status.chat).toBe('Чат обновляется')`
- [x] Track last successful roster timestamp separately from current availability;
  render scoped states and an explicit roster reconnect action.
- [x] Verify session/logout teardown clears snapshots and status independently.
- [x] Run focused Vitest workspace/roster tests and browser fault scenario.

## #80 — bounded protected refreshes

Files: `clients/web/src/workspace/protected_refresh/{gate.ts,gate.spec.ts}`, native
`workspace_realtime.ts`, `realtime/realtime_event_delivery.ts`,
`realtime/realtime_connection_types.ts`, `realtime/realtime_store.ts` and tests.

- [x] Measure 1/20/50 hints for active/hidden conversations before and after.
- [x] Test one fetch for a burst, at most one in-flight fetch/resource, dirty
  follow-up, old-page edit/delete, revision preservation and immediate revoke.
  `expect(maxConcurrent).toBe(1); expect(finalRevision).toBe(50)`
- [x] Add short-window resource gates and native delivery batching; advance
  durable cursor only after successful protected refresh, retain failures/replay.
- [x] Run focused Vitest delivery/workspace/history tests and actual hint burst.

## #56 — actual reservation and release

Files: `tools/qa/upload_reservations/{run.py,stack.py,client.py,measure.py,
test_measure.py}`, existing `tools/qa/client_lifecycle/stack.py` as fixture reuse.

- [x] First test rejects idle-only evidence, missing release and foreign origin.
  `with self.assertRaises(AssertionError): validate([0, 0, 0])`
- [x] Start owned PostgreSQL/API/TLS with a bounded tmpfs attachment volume.
  Run two held multipart uploads, measure exact statfs/real reservation gauge,
  require capacity-limited 507, release on cancel/success and bounded retry 201.
- [x] Run an independent build during sampling; retain numeric outcomes only.
- [x] Run fixture tests and actual isolated scenario; remove owned resources.

## Integration

- [x] Inspect explicit changed file sizes/status; run native Web/Go/contracts,
  traceability and docs checks. Record observed acceptance and limitations.
- [x] Commit explicit paths, publish PR, fix failures and verify its source in CI.
  Integration is recorded in [PR 128](https://github.com/BOOHTACORD/BOOHTACORD/pull/128);
  compatible signed rollback and broader production/device gates stay open.
