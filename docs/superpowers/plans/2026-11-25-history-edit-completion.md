# History editing retention completion plan

> Execute the checklist sequentially in the isolated worktree. Preserve existing behavior and require real-stack evidence before closing #141.

**Goal:** Complete issue #141 on current master, preserving unsaved TEXT edits through bounded-history eviction and validating the original Web acceptance criteria.

**Architecture:** Reuse the existing scoped history editor registry and one retained focused DOM row. Keep the 500-message cache, reversible paging, protected APIs, session isolation and virtualized rendering. Fix only behavior demonstrated by a focused regression.

**Tech Stack:** Vue/TypeScript, Vitest, Playwright, Go/PostgreSQL local QA stack.

## Operating brief

- Classification: split_first, then one implementation/review packet per defect.
- Implementation leaf: `clients/web/src/conversation/history_window/measurement_delivery`; the historical editing-state fix is already in master.
- Verification leaf: `tools/qa/history_edit_retention`, reached from the existing critical lifecycle journey.
- Integration edges: `use_text_history_list.ts`, `editing_pin.ts`, `MessageItem.vue`.
- Direct tests: editing registry/async tests and `tests/chat_rhythm/history_edit_*`.
- Runtime owner: existing local-features chat acceptance, fresh isolated resources.
- Baseline: `35f52194e4323b6a9dbbeb66f520af747b2606f8`.
- Ratchets: target 100/hard 120 lines; target 8/hard 16 production files and direct tests per leaf.
- Unknowns: whether the historical failure still reproduces; current real-stack gate readiness; ResizeObserver warning cause.
- Stop condition: applicable issue criteria PASS, actual PR CI green, merge to master; unavailable acceptance remains explicit and does not close its gate.

## Steps

- [x] Run existing focused unit/browser regressions on unchanged master: 13 unit and 28 browser checks PASS; observer-loop errors confirmed.
- [x] Establish fresh built-Web/API acceptance: critical-stack 20-dataset wide matrix and scoped 393px editor/conflict/focus PASS; existing browser controls remain required by the full feature gate.
- [x] Add a failing observer-loop browser regression: 4 errors at 1440px, 3 at 393px before the fix.
- [x] Batch size updates in the next rendering frame, preserving observations and cancelling pending callbacks on unmount; 28 nearest unit and 30 browser checks PASS.
- [x] Register chat acceptance and attach the 1000-message regression to the existing critical lifecycle journey; the finite wide matrix remains an explicit owned command.
- [x] Run focused tests, Web build and registered critical journeys at both widths; inspect all eight changed history captures and both critical editor captures. Two setup failures are retained and resolved by same-source scoped browser rechecks (20/20 and 28/28, zero skips).
- [x] Recheck 20 finite owned history datasets: maximum 500 cached, 30 DOM rows and zero shift at ten measured paging anchors. Keep the historical before/after performance study distinct.
- [x] Record candidate source, observed results, setup failures and physical/native limits in the evidence record.
- [x] Run the mandatory reviewed commit preflight and generated companion checks; inspect status/file sizes and stage exactly 19 reviewed files. Hosted CI remains required before merge.
- [ ] Open PR, wait for actual head/base CI, resolve failures without weakening gates and merge when green.
- [ ] Update #141 with final implementation/acceptance status; close only if all its required criteria pass.
