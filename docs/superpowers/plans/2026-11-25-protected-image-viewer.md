# Protected image viewer implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement these steps in this chat.

**Goal:** Complete FE-53: protected TEXT/DM image viewing with reliable modal ownership, focus, resource cleanup and real browser/ACL acceptance.

**Architecture:** Keep existing protected preview/original endpoints and attachment-card entrypoints. Test the original behavior first; move viewer implementation into one bounded native Vue leaf and retain compatibility forwarding entries. A changed preview identity closes and cancels the old viewer; late requests cannot change current state.

**Tech Stack:** Vue3/TypeScript, Vitest, Playwright, existing owned Go/PostgreSQL QA stack.

## Task 1: Real browser regression before implementation

Files: `clients/web/tests/protected_image_viewer/fixture.{html,ts}`, `image.ts`, `clients/web/tests/accessibility/protected_image_viewer.browser.spec.ts`.

- [x] Use production TEXT/DM attachment cards, same-origin routed PNG responses and normal application styles.
- [x] Verify load, explicit download, focus trap, Escape/focus return and viewport bounds at 1440/393/320px.
- [x] Test changed scope with the same attachment ID and non-focusing trigger activation. Observe failure on the original implementation before editing it.

## Task 2: Bounded viewer lifecycle

Files: canonical `clients/web/src/conversation/protected_image_viewer/{component.vue,dialog.ts,preview.ts,viewer.css}`, compatibility entries `ProtectedImageViewer.vue`, `protected_image_preview/use_protected_image_preview.ts`, `protected_image_preview/viewer.css`.

- [x] Preserve rendering/styles, same-origin/no-store fetch, protected original links, retry and 404/410 presentation.
- [x] Bind return focus to the actual opener, close on resource identity change, reject stale close/request events and abort cancelled preview requests.
- [x] Replace source-string assertions with behavior tests; verify 403/404/410/500/decode failure, reopen and unmount cleanup.

## Task 3: Acceptance and merge

- [x] Exercise actual protected uploads/previews/originals in TEXT/DM and unauthorized requests on an isolated server; inspect desktop/mobile captures and available real browser targets.
- [x] Register feature parity/acceptance and update the bounded task/evidence without claiming unrelated Flutter/physical platform gates.
- [x] Run the nearest tests, native contracts, traceability, generator checks and preflight; review exact paths/sizes before staging.
- [ ] Merge only after successful exact-head hosted CI and verify master contains the tested tree; final results belong in the PR.

Preservation: no API/ACL policy, authentication, media or deployment change. Original failure reports remain evidence; no baseline is approved to silence a difference.
