# R1 socket-owned protected recovery implementation plan

> Execute inline in the current chat; preserve unrelated checkouts and gates.

**Goal:** Complete the delayed-old-recovery/new-empty-roster regression on current
master and correct any socket ownership defect it exposes.

**Architecture:** Keep the existing realtime queue, roster store and HTTP owners.
Invalidate coalesced recovery work at socket end without replaying durable hints
or cancelling unrelated initial/UI loads. Verify real API/WebSocket transport in
the owned loopback fixture; record its limits separately from physical media.

**Tech stack:** Vue/Pinia, Vitest, Playwright, Go/PostgreSQL/LiveKit, Python QA.

## Baseline and boundary

- Base: `81641df88ce09054ff47920791c965e630eb3e0c`.
- Route: `clients/web/src/workspace/protected_refresh` socket ownership.
- Existing Web queue fencing is already merged; do not reimplement it.
- Existing pending/running protected refreshes currently survive socket end.
- Preserve same-socket coalescing, 256-hint limits, cursor/replay, ACL and media.
- Target 100/hard 120 lines per touched source, no aggregate restructuring.

## 1. Reproduce before implementation

- [ ] Add a regression to `workspace/realtime_incarnation.spec.ts` invoking the
  production workspace recovery callback twice across socket end/start.
- [ ] Hold the first topology refresh unresolved. Expect a second transport call
  and completed new recovery before releasing the old request.
- [ ] Run `npx vitest run src/workspace/realtime_incarnation.spec.ts` from
  `clients/web`; retain the expected failure on current master.
- [ ] Add gate regressions for cancelling pending work and suppressing dirty
  follow-up fetches belonging to an invalidated socket.

## 2. Isolate socket-owned refresh work

- [x] Add `protected_refresh/scope.ts`: close the old gate and create a new
  coalescer for each socket incarnation. Old callbacks retain their closed gate.
- [x] Expose gate admission and pass it to topology's scoped refresh, fencing
  late success/error and superseding an old in-flight read.
- [x] In `workspace_realtime.ts`, renew the protected scope on socket end;
  use a fresh permissions request during full recovery.
- [ ] Audit the exact underlying HTTP store owners for late-result protection;
  add owner-side regression/fix if a stale result can overwrite newer state.
- [ ] Run the nearest workspace/realtime/roster tests and TypeScript build.

## 3. Real transport regression and acceptance

- [ ] Extend registered connection-status QA with delayed recovery, populated
  old roster, reconnect and new empty roster, preserving an applied durable
  cursor. Releasing the old response must leave the new state unchanged.
- [ ] Use isolated API/PostgreSQL/LiveKit; retain source identity, assertions,
  screenshot observations and ownership-checked cleanup.
- [ ] Run `tools/qa/local_features/check.sh --feature connection_status
  --platform web --base origin/master --real-stack` and review source-size PNGs.
- [ ] Record backend generation/multi-session and Flutter socket-owner checks
  where applicable; missing runtime proof stays explicitly NOT_RUN/BLOCKED.

## 4. Review and tracking

- [ ] Write focused evidence under `evidence/qa/` with RED/GREEN and actual scope.
- [ ] Inspect status/file sizes, stage only selected paths, open a `codex/*` PR
  and inspect required CI on the exact head.
- [ ] Refresh #689 with completed subcases and remaining R1 requirements;
  do not mark full R1 or the parent complete without the corresponding proof.
- [ ] Recheck current remote master so the recorded baseline cannot be stale.
