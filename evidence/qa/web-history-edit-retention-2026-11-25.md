# Web history retention and size delivery — issue #141

Base: `35f52194e4323b6a9dbbeb66f520af747b2606f8`, 2026-11-25.
Runtime candidate: `35f52194e4323b6a9dbbeb66f520af747b2606f8 worktree-sha256=79ff29ddf2a4aa651ad2e78f0dc784c4d37df42098c94298a53d699e838f306b`; result documentation was finalized afterward.

## Problem and implementation

The existing editor registry already retained edits through eviction: unchanged
master passed 13 nearest unit and 28 browser checks. Ordinary paging still caused
ResizeObserver-loop errors (initial negative control: 4 at 1440px, 3 at 393px).
`useHistoryWindow` applied reactive measurements inside observer delivery,
triggering another layout/virtual-row update in that delivery cycle.
Measurements now coalesce by target and apply in the next animation frame.
Unobserved rows are removed; disposal cancels the pending callback and clears data.
Browser errors are not intercepted or suppressed. Cache limits, scoped editing,
one focused DOM pin, reversible paging and server ACL are preserved.

## Current checks

- PASS: 28 nearest history-window unit tests and 30 focused browser tests.
- PASS: observer regression at 1440/393px, after two rendering frames; 3 fixture guards.
- PASS: full Web unit suite, build, contracts, 39-requirement traceability,
  product-map, flow-contract and signal-catalog checks.
- PASS: critical built-Web/API journeys at 1440px and 393px, including protected
  preview refresh and real 1000-message eviction/conflict/selection/focus checks.
- Current required browser checks PASS after explicit same-source scoped rechecks.
  The original overall feature report remains FAIL: screen_profile skipped one
  test without isolated credentials; search_sessions found an orphaned Vite on 4945.
  A fresh owned SFU with short-lived in-memory tokens passed screen_profile 20/20;
  verified removal of our stale Vite allowed search_sessions 28/28. Both rechecks
  had zero skips and identical before/after source fingerprints. Raw results remain intact.
- Eight changed history captures and both critical AppShell editor captures were
  inspected at original resolution: focus/selection and controls fit, no clipping.
  No unrelated visual baseline is approved by this review.
- Hosted PR CI is pending at commit time; its final result is tracked on the PR.

```sh
npm test --prefix clients/web -- src/conversation/history_window/
node --test tools/qa/history_edit_retention/test_seed.mjs
# In clients/web:
npx playwright test -c tests/chat_rhythm/playwright.config.ts --grep 'history edit|history resize'
# Pinned toolchains, installed Web dependencies, local Linux Docker:
python -m tools.qa.history_edit_retention.run
./tools/qa/local_features/check.sh --platform web --feature chat --feature auth \
  --feature connection_status --feature idle_afk --feature screen \
  --feature support --feature voice --base HEAD --real-stack
```

The critical lifecycle journey now runs the real-API 1000-message regression
before session revocation; its media/preview checks remain required.

## Finite owned history matrix

The valid UUIDv4 critical-stack wide record passed all 20 datasets below.
That run's overall FAIL is retained: its later 393px check targeted an icon in
the closed drawer. Opening navigation with the existing helper resolved the
scoped 393px rerun, which passed with exact draft/selection and real conflict saving.
Both widths subsequently passed in the shared critical journey on final code.

| Messages | Reply % | Unavailable | Cached | DOM rows | Anchor shift px | First-page nav ms | Post-GC heap bytes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 50 | 0 | no | 50 | 21 | n/a | 173 | 10492984 |
| 50 | 50 | no | 50 | 15 | n/a | 157 | 9756640 |
| 50 | 100 | no | 50 | 14 | n/a | 170 | 9822792 |
| 50 | 50 | yes | 50 | 15 | n/a | 167 | 9948020 |
| 50 | 100 | yes | 50 | 14 | n/a | 175 | 9940684 |
| 500 | 0 | no | 500 | 21 | n/a | 164 | 11499540 |
| 500 | 50 | no | 500 | 15 | n/a | 168 | 11083860 |
| 500 | 100 | no | 500 | 14 | n/a | 175 | 11267604 |
| 500 | 50 | yes | 500 | 15 | n/a | 154 | 11352384 |
| 500 | 100 | yes | 500 | 14 | n/a | 162 | 11384900 |
| 5000 | 0 | no | 500 | 30 | 0 | 146 | 12849816 |
| 5000 | 50 | no | 500 | 24 | 0 | 157 | 11897280 |
| 5000 | 100 | no | 500 | 23 | 0 | 79 | 11907340 |
| 5000 | 50 | yes | 500 | 24 | 0 | 143 | 11998088 |
| 5000 | 100 | yes | 500 | 23 | 0 | 143 | 12018476 |
| 10000 | 0 | no | 500 | 30 | 0 | 143 | 13088044 |
| 10000 | 50 | no | 500 | 24 | 0 | 166 | 12137896 |
| 10000 | 100 | no | 500 | 23 | 0 | 149 | 12153472 |
| 10000 | 50 | yes | 500 | 24 | 0 | 148 | 12206332 |
| 10000 | 100 | yes | 500 | 23 | 0 | 148 | 12233556 |

`n/a` means no further older page existed, not a measured zero. All ten measured
anchors shifted 0px. Timings include local initial-page navigation, not INP or
full-history mount time. Heap is absolute after explicit GC, not peak or delta.
The earlier before/after performance study remains
[historical evidence](https://github.com/BOOHTACORD/BOOHTACORD/blob/78e670d6df850dae77182290bb207dc4453f74ce/evidence/qa/open-issues-2026-10-27/isolated-history-profile-matrix/README.md).
Its index/eviction algorithms are unchanged; the virtual-window diff adds only
the detached-row type field. Historical timings are not relabelled as current.

## Scope, preserved failures and cleanup

Only fresh label-owned API/PostgreSQL/LiveKit/Egress resources and synthetic data
were used; application responses and ACL decisions were not mocked. SQL creates
finite stress fixtures, not proof of business-API admission of legacy references.
The fixture's initial reload precedes editing; eviction/return, selection and
conflict checks do not reload. The registered chat suite also checks delayed row
expansion, reading anchors, bounded image viewers and TEXT/DM state preservation.
Earlier setup errors and the preliminary REST-only run are retained, not promoted
to full acceptance. Image review rejected that run's non-v4 fixture identifiers
and missing SFU; explicit UUIDv4 validation and the existing critical stack replaced it.
Source stability and owned-resource cleanup passed. No real user history,
sessions or calls changed. Physical/native clients, audible media and production
are NOT_RUN for this packet; broader acceptance issues remain separate.
