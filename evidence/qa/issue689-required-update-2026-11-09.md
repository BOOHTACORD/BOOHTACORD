# Issue 689: minimum client release and required-update UI

The catalog and public policy accept optional `minimum_release_order`; the server rejects values below one or above the selected target release order. Omission and null preserve the earlier behavior. This is a policy mechanism, not server-side enforcement for old clients.

Focused Go catalog tests, catalog schema tests, OpenAPI lint/parity and Flutter/Web evaluator and update UI tests passed on the working tree. Flutter analysis of the initially implemented files passed; a subsequent error-handling change requires its final rerun. Web production build passed before the new gate component was added and must be rerun for the final source.

The native scenario `integration_test/update_required_test.dart` ran on owned Android emulator `emulator-5554` against the real local API using a synthetic catalog and pinned TLS; it passed with source identity stable across the run and no mocked components. It verified that the API's minimum creates the non-snoozable screen and retains the mounted sign-in draft. The screenshot `android-required-update.png` was reviewed at 1080x1920, SHA-256 `72de8175ceffe5004355e1d8047fd6ee940c2d447bcbdb221efd5e9eb8221794`: the title, explanation, test summary and update button are legible and within the viewport. No installer was opened. This runtime predates the later launch-error UI change and must be rerun on final source.

The browser component scenarios used synthetic API responses and passed at 393x900 and 1440x900; screenshots reviewed at original resolution, respectively SHA-256 `db3bd34174ac6808c7e6785dd2f5bb633c7219e51332ef09546ac8b68897f8e3` and `d94bc3737a7ee393bc4a4263937a918130fb963c7e7a1daf799ead986a366f6b`. The modal is legible, the background is inert, its focus is on the update action, and the synthetic draft remains mounted. Mocked browser transport is not real-stack acceptance.

Old installed native versions do not implement this policy, current client checks start asynchronously, and accepted legacy sockets are not denied with an actionable update message. The prepare/transition/final sequence, signed releases, full device matrix, rollback and server-side enforcement remain NOT_RUN/BLOCKED. This work does not establish compatibility for those old versions or production readiness.

## Later runtime follow-up

The scoped Android required-update scenario was repeated after the launch-error handling change, together with three other native targets, on a later dirty worktree. See `issue689-android-corrected-runtime-2026-11-09.md` for its source fingerprint, results, visual review, failed environment attempts and remaining limitations. The new test did not open an installer or establish old-client enforcement.
