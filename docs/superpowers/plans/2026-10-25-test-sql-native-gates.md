# SQL and native test protection implementation plan

**Goal:** Execute the three audited SQL predicates and the missing Android/macOS suites, with explicit protection, commands, platforms, triggers and results.
**Architecture:** Preserve production behavior and existing unit checks. Add leaf-local PostgreSQL tests using the existing isolated-schema fixture and embedded migrations. Extend existing native entrypoints and fail on missing, skipped or failed test results.
**Tech stack:** Go/pgx/PostgreSQL, Python unittest, Gradle JUnit, Flutter.

Operating brief: workflow_class=split_first; task_size=medium; structure_mode=structure_no_rg; search_stage=exact_edges.
Base: 25024b4e; branch: codex/test-sql-native-gates. The earlier audit patch is not present and is a separate prerequisite, not silently applied here.
Backlog owners: T-040 (T-010,T-020), T-044 (T-040,T-041), T-030 (T-004,T-005,T-022), T-051 (T-050), T-060 (T-007,T-030,T-044,T-050,T-052,T-054).
Doctrine: native manifests/imports, first-pass preservation, one leaf per sequential packet; target 100/hard 120 lines per new source, target 8/hard 16 production/direct test files.

- [x] SQL edit packet: add `backend/internal/chat/edit_text_message/postgres/integration_{fixture,authorization}_test.go`; exercise own/foreign author, stale revision, archived/deleted/wrong channel and unchanged denied state.
- [x] DM packet: add `backend/internal/storage/authorize_direct_message_attachment/postgres/integration_{fixture,authorization}_test.go`; exercise both participants, outsider/admin, blocked peers, missing pair and unchanged state.
- [x] Descriptor packet: add `backend/internal/media/publish_screen_descriptor/postgres/integration_{fixture,authorization}_test.go`; exercise active/revoked session/lease, closed/archived channel, blocked account, identity mismatch; denied calls must not publish or change receipts.
- [x] Baseline command from backend: `go test -json -count=1 ./internal/chat/edit_text_message/postgres ./internal/storage/authorize_direct_message_attachment/postgres ./internal/media/publish_screen_descriptor/postgres`; validate events with the existing no-skip verifier. Execute each audit OR TRUE mutation separately, require its named negative test to fail, restore exact bytes and repeat baseline.
- [x] Android packet: add `tools/verify/android_unit/` JUnit validation and runner/tests; invoke real plugin `testDebugUnitTest` tasks from the existing two-mode Kotlin entrypoint. Require every expected class/case, reject skips/failures/missing results, retain XML in CI. Correct test-engine dependencies if native configuration requires it.
- [x] macOS packet: execute LiveKit screen capture engine tests on Apple in native CI/release; include every copied QA unit test in both Mac QA build paths and verify selection with focused tests.
- [x] Documentation/evidence packet: `docs/ci/test-protection.md` maps suite -> invariant -> command -> platform -> mandatory trigger -> artifact. Record baseline, mutation failures, discovery and platform limits in `evidence/ci/test-sql-native-gates-2026-10-25.json`.

Checks: nearest Go packages and no-skip verifier; Python unittest for native runners, JUnit failure/discovery handling, Flutter/workflow/release policy; action pin and CI selector validators; diff whitespace and changed file sizes.
Stop condition: all available checks pass, each SQL mutation is killed, missing native routes are wired and retained; unavailable Android/macOS execution remains NOT_RUN and cannot close a platform/media release gate. No test deletion or application of the remaining 43 consolidation decisions in this packet.

Execution note: implementation and available verification completed in this worktree. PostgreSQL local runtime is 16.14, CI remains 17.6. Android/macOS SDK runtime checks remain NOT_RUN; their mandatory CI routes and failure semantics are implemented. Existing large workflow YAML boundaries were preserved; no SG-CONVERT claim is made.
