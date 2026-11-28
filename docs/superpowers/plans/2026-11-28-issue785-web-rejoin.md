# Issue 785 Web rejoin investigation plan

> Execute inline, one bounded diagnostic or implementation packet at a time.
> Do not invent a production fix before a reproduced failure identifies its owner.

**Goal:** Reproduce the observed post-logout/login Web voice failure, identify
its cause, fix that cause with a failing regression, then deliver through CI.

**Architecture:** Preserve the original browser controller and owned API/SFU
fixture. Observe only bounded state enums, HTTP status/error codes and aggregate
transport counters. Keep credential, cookie, message and media payloads private.

**Tech Stack:** Vue/Pinia, LiveKit client 2.22.3, Playwright, Go, local Docker.

## Operating brief

- workflow_class=split_first; task_size=large; structure_mode=structure_no_rg.
- Base master: 536f39c5dbede4e8b73f43178d80c468119b3b01.
- Backlog T-022, dependencies T-006/T-020; requirements unchanged.
- Diagnostic entry: tools/qa/client_lifecycle/journey/scenario.mjs.
- Exact failing edge: critical_client_acceptance/mini_player_ui.mjs logout,
  login, listener join and selectVisibleStream; original assertions preserved.
- Candidate leaf: clients/web/src/voice/connection_state/join.ts; follow only
  its admission, SDK join and ownership edges after observation identifies phase.
- No production deployment, recording, OS permission bypass or generic retries.
- Limits: target 100/hard 120 lines; target 8/hard 16 implementation/direct tests.
- Stop: same failure recorded with phase/cause; regression fails before fix;
  nearest unit/build and original desktop/mobile actual-stack acceptance pass;
  CI succeeds, expected-head merge and master tree are verified, issue updated.

## Diagnostic packet

- [x] Create a clean Linux source snapshot at the exact master commit.
- [x] Retain the prior first FAIL; never relabel it as PASS.
- [x] Add temporary read-only browser observer outside the intended diff: record
  admission status, RTC/ICE/signaling enums and classified UI failure, no tokens.
- [x] Retain controllers 1-3 PASS and controller 4 unrelated roster FAIL.
  Fifth NOT_RUN; superseded by natural and deterministic before/after witnesses.
- [x] If rare, repeat the real viewer/logout/rejoin segment while the independent
  publisher remains active; record the experimental harness hash separately.
- [x] Select the failing production leaf from the observed phase. Write its
  implementation packet with concrete regression before changing production.

## Verification and delivery packet

- [x] Run the leaf regression before/after; preserve logout, revoke and ACL rules.
- [x] Run nearest native Web tests/build and registered actual-stack acceptance.
- [x] Inspect scoped screenshots at source resolution and retain source binding.
- [ ] Run Contracts, parity/generators and fresh explicit preflight review.
- [ ] Commit explicit paths, open ready PR, await all selected exact-head CI.
- [ ] Merge with expected head; verify parents, tree and clean worktree.
- [ ] Update #785 with cause, tests, delivery and remaining physical/iOS gates.

## Confirmed implementation packet

- The real Web failure reproduced both with and without signaling interception.
  Lease/credential succeeded; SFU returned HTTP 500, `could not find any available
  nodes`, before ICE. A second witness exposed the exact SDK WebSocket reason;
  its node was SERVING with fresh statistics 75 ms after the failed handshake.
- Scope: recover one early typed WebSocket failure after 2 s, inside the original
  20 s connect budget. Keep the exact lease and revalidate its credential/ACL.
  No retry of lease acquisition, microphone capture, device changes, authorization
  failures, cancellation, timeouts or unknown exceptions.
- Fence retry/capture by admission generation and exact pending revocation;
  honor a newly returned microphone restriction. Keep Flutter unchanged.
- Preserve and split the oversized session facade and test fixtures by their
  existing admission, browser-resume and microphone-control responsibilities.
- Deterministic acceptance removes one owned SFU discovery entry after a
  heartbeat; its ordinary heartbeat restores it. Require an actual HTTP 500,
  one lease, two same-lease credential checks and decoded stream recovery.
- First leaf regressions: 6 failed / 8 preservation cases passed before code.
  Initial legacy baseline: 26 tests passed. Candidate full Web unit suite:
  2120 passed, zero skips; build passed with the owned public origin configured.
- Retain every diagnostic outcome, including unrelated roster-button race and
  login rate-limit failures; neither is claimed repaired by this packet.

Final local verification: eight selected features; 29 stages PASS, both
actual-stack widths recover the verified initial HTTP500 with one lease and
advancing decoded video. Contracts PASS; runtime/source binding is in evidence.
Hosted CI and merge delivery are recorded in the PR/issue after they complete.
