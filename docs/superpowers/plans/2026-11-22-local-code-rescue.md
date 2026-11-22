# Local code rescue implementation plan

**Goal:** Integrate useful residual fixes into current master, prove the changed behavior, merge green CI, and remove redundant local branch refs without losing dirty work.

**Architecture:** Adapt individual capabilities to current entrypoints. Preserve the managed session pool, Unicode guild settings, screen-dialog heading and current administrative controls. Do not restore obsolete SSE routes, old catalogs, monolithic clients, or disposable pools.

**Route:** `split_first`; sequential implementation packets followed by `review_gate`, branch sync and local cleanup. Native manifests: `backend/go.mod`, `clients/web/package.json`, `clients/flutter/pubspec.yaml`. No production deployment.

## 1. Update identity consistency

Files: `contracts/client-update-evaluator.fixtures.json`, Web `updates/evaluator.ts`, Flutter `features/updates/evaluator.dart` and a small identity comparison helper.

- [x] Add shared cases where an identical release ID has a different order, version or declared build; expect `identity_conflict`. Add matching Android split-APK identity to preserve ABI behavior.
- [x] Run `npm test --prefix clients/web -- src/updates/evaluator.spec.ts` and `flutter test test/updates/evaluator_test.dart`; confirm the contradictory cases fail first.
- [x] Implement the identity comparison before returning up-to-date, preserving required-update policy and installed-package checks.
- [x] Re-run both evaluators and their required-update suites.

## 2. Administrative save lifecycle and clipboard feedback

Files: `role_permissions/save/handler.dart`, `load/handler.dart`, `actions/handler.dart` and focused Flutter admin tests; `screens/admin_ui/copy_reset_link/handler.dart` and reset-link tests.

- [x] Reproduce removal of the panel while delete confirmation is open; require no post-dispose mutation and zero save requests.
- [x] Fence saves with `mounted`, current editable member role, load/save state and the captured revision/draft after awaiting confirmation. Stop post-save reloads after disposal.
- [x] Test a successful copy followed by a failed copy. Clear prior feedback before the new attempt and emit success only after a successful write.
- [x] Run current administrative accessibility/role surface tests. Keep valid `main()` wrappers from master instead of importing broken historical tests.

## 3. Session first-check spread

Files: `backend/internal/realtime/connect_session/session_monitor.go`, `session_monitor_spread.go` and focused Go tests.

- [x] Port tests for a stable digest-derived delay in `[0, interval)` and unchanged full interval for an unknown digest; add nonpositive-interval coverage.
- [x] Port the timer schedule while retaining the current revalidation deadline, identity checks, observer and close behavior.
- [x] Run `go test -count=1 ./internal/realtime/connect_session` and current session-pool tests. This does not claim a measured capacity improvement.

## 4. Isolated load harness

Files: `tools/qa/backend_load/{client,metrics,run,safety,test_safety}.py`, a redirect regression test and usage documentation.

- [x] Restore the small read-only harness in its current tools route. Before using it, add two owned-loopback-origin tests that reject HTTP redirects instead of treating the redirected destination as a successful API request.
- [x] Install an explicit redirect rejection handler in the opener. Keep account, address, duration and concurrency bounds; log aggregate statuses only.
- [x] Test no cross-origin requests and unchanged successful same-origin requests. Do not run load against production.

## 5. Existing fixes and acceptance

- [x] Run guild name validation and managed pool tests to establish that the current implementations already replace the unsafe archived versions.
- [x] Verify the existing screen-dialog label test in both modes; import no obsolete UI hunk.
- [x] Update the applicable `tools/qa/local_features/features.json` decision and register focused regression scenarios.
- [x] Run the selected canonical local-feature check on the owned stack, with applicable native runtime; inspect captures and record actual results.
- [x] Run contracts, relevant backend/Web/Flutter suites, generators and `python -m tools.ci.preflight.run --base origin/master`. Provide a truthful readiness review; hosted-only gates remain pending until CI runs.
- [ ] Inspect status, exact changed files and sizes, stage explicit paths, commit, push and create a non-draft PR. Wait for exact-head green CI; repair failures without weakening checks, then merge.

## 6. Local branch cleanup

- [ ] Refresh master after merge. Inventory branch refs and current worktree ownership again.
- [ ] Delete unused local refs only when their commits are ancestors of updated master, or when their exact tip is a redundant alias retained by another needed ref. Preserve active/dirty worktree branches, unique unfinished code and stash.
- [ ] Record deleted names and reasons outside the committed diff. Verify remaining refs and dirty source hashes. Never force-remove a worktree or delete project directories.

**Stop condition:** merged verified fixes, green required checks, recorded cleanup with remaining unique work explicitly preserved. Server deployment, release publication and media/capacity acceptance are outside this request.
