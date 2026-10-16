# DW-007 / issue #346 — compact Web result presentation

Status: PASS for scoped local Web acceptance. Remote CI and merge/closure are verified separately in the PR.
Date: 2026-10-16. Base: `2ee7e9ec62684f56acf9dd3e456791766a732fa6`.
Scope: Web search, pins, personal mentions, readonly archive, conversation files and quick jump. Dependencies #340/#342 were completed before this work. Parent #339 and native/media gates are not closed by this record.

## Implementation and test boundaries

The six surfaces share a list hierarchy and metadata/action styling. Advanced filters are disclosed with active values and reset outside the disclosure. Message snippets are bounded, plain text with literal highlighted query context; links remain usable in the full message reached by the context action. Full names are available on keyboard focus and filenames through a touch/keyboard disclosure. Search modes have one bounded content scroll owner below their persistent header. Query, filters, selected conversation, draft and nonzero result scroll are checked across context navigation and return.

401/403/404 clear stale search, file (channel and DM), mention and archive rows. Transient pagination failures retain the existing page and retry cursor. Existing authenticated APIs, server ACLs, DM privacy and readonly behavior are preserved; there is no API contract change.

Focused tests preceded the implementation. Local diagnostic logs and captures are kept under `.out/issue346/`; they are not committed. Initial fixture failures in `before.log` included an invalid history fixture kind and are not presented as product defects. Corrected baseline failures are in `before-corrected.log` (9 failures, 1 pass), `mentions-before.log`, `archive-before.log`, `archive-catalog-before.log`, `dm-denial-before.log`, and `focus-before.log`. `snippet-before.log` failed with the intentionally missing new helper; `link-before.log` completed after the helper was written and is not a red baseline. Calendar controls already passed the four new width/large-text checks; their existing flex basis is retained.

## Before / After provenance

Fresh Before frames use exact production sources from base master, not a changed screenshot baseline. The private original Web tour is unavailable and was not claimed as inspected. `before-sources.json` records SHA-256 hashes, an empty tracked source diff and the absence of the new stylesheet import during capture. `before-wide.log` intentionally fails new presentation assertions after writing the 320/1440px Before frames. Candidate bytes were restored in a `finally` block. Corrected 390px Before frames are retained separately. After frame hashes and source-resolution observations are recorded in the adjacent JSON.

## Focused results

- Complete Web unit suite: PASS, 1545 tests / 473 files (`unit-ready.log`).
- New presentation suite: PASS, 68 cases (`presentation-candidate.log`): six surfaces at 320/390/1024/1440px and 100/200% text, actual Chromium 200% browser zoom, touch, keyboard, axe, inner overflow bounds, filenames, query-context preview, stale ACL state and transient retry.
- Existing search-session suite: PASS, 22 cases (`search-owner.log`); exact nonzero scroll retention is preserved with the new scroll owner.
- Existing inclusive search-date suite: PASS, 8 UTC/New York cases (`dates.log`).
- Existing control consistency: PASS, 26 cases (`controls.log`).
- Existing conversation action disclosure/file layout: PASS, 18 cases (`files-regressions.log`).
- Web production build: PASS (`build-final.log`); the earlier `build.log` failed because the command omitted required `VITE_PUBLIC_ORIGIN`.
- Specification traceability: PASS, 39 indexed requirements; approved Windows brief was unavailable on this Mac, so this proves index consistency only.

## Integration diagnostics (not final acceptance)

Exploratory runs use an isolated, disposable local PostgreSQL/Go/Tempo/LiveKit stack and synthetic accounts. `real-probe.log` exercised the six new desktop journeys but failed an older assertion assuming date filters were always expanded; that scenario now explicitly opens the disclosure. `real-probe2.log` / `real-probe3.log` found zero-width composer text input after adding a pending upload on touch. Composer/pending-upload production code is unchanged in this issue; no runtime base reproduction is claimed. This independent observation remains outside DW-007 acceptance and must not be represented as a passing upload-queue editing check. The result-panel fixture instead uploads and publishes through the actual secure API while preserving an existing composer draft. Captures/geometry for the observation remain in `real-probe3/393/compact-upload-ready.*`.

`real-probe4.log` failed a later navigation transition; the scenario now waits for the quick-jump panel and scrim to close. `real-probe5.log` passed the full touch lifecycle, including all six result surfaces and stack cleanup. This was a dirty-source diagnostic run; later exact target-ID and alternate-channel quick-jump assertions require the final clean-source rerun. None of these diagnostic successes replaces the mandatory registered all-feature gate.

## Visual-review follow-up

Native-resolution comparison found quick-jump rows still showing browser list numbering. A computed-style regression was added first (`quick-list-before.log`: FAIL, decimal instead of none), then the list was registered with the shared `result-list` class. Two all-feature attempts were deliberately interrupted before integration while visual review continued; they are not acceptance evidence. Desktop inspection then found stretched quick-jump grid tracks (`quick-height-before.log`: FAIL, row 357px), fixed with start-aligned list tracks. Large-text inspection found overflowing avatar initials (`avatar-before.log`: FAIL, 60px vertical overflow), fixed with rem-scaled avatar/grid geometry and a single text line. All 68 focused cases pass after these corrections (`presentation-visual-final.log`). The immutable `.out/issue346/after-reviewed` captures preserve this reviewed candidate before the mandatory run.

## First completed all-feature attempt

Clean source `869e3a12` / run `20261016-195533`: overall FAIL, 20/21 stages PASS. Both authenticated real-stack journeys (1440 desktop and 393 touch) passed, including exact message targets, alternate-channel quick jump, preserved draft/filter/query/nonzero scroll, media-fault/reset/tracing regression checks and owned-resource removal. The one failure was the existing mentions-inbox test expecting the deliberately removed redundant “упомянул(а) вас” copy. The test now checks the visible source and exact timestamp instead; its author, private-body absence, pagination and exact DM-message target assertions remain. The failed report is retained; a new complete clean-source gate is required.

## Final local acceptance

PASS: `.out/local-features/20261016-201130` on clean source `16a1a39789efccfee8e810dfe513c85f7848c834` (empty tracked diff SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`). All 21 stages passed: complete unit suite, production build, 17 registered browser suites and authenticated desktop/touch lifecycles with owned resources removed. The earlier `20261016-200345` report remains FAIL for the 20s media lease-notification timeout after all DW-007 journeys; the unchanged-source complete retry passed without removing or weakening checks. The refreshed mentions suite retains privacy, metadata, pagination and exact-target assertions.

Manual visual review: PASS for the selected scope. Before/After inspected for all six surfaces at 320/390/1440px, large text at 320px, and 24 actual 200% Chromium zoom scenes (CSS 320/390/1024/1440). Long names wrap on focus without horizontal overflow; list rows do not stretch; filename disclosure preserves full text. Real-API desktop/touch frames show active filter/reset controls, context actions and readonly archive details. Some selected real-API captures precede the later unrelated notification timeout; their overall report is explicitly retained as FAIL and the final run tests identical production code. Browser tap highlights/existing toolbar hints are recorded as transient capture conditions, not approved persistent baselines.

The adjacent JSON records the accepted source, per-file code hashes, raw gate report digest, retained failed attempts, Before source provenance, original/cropped PNG sizes and SHA-256 hashes, and exact real-stack outcome flags. The runner's raw `REVIEW_REQUIRED` status is preserved; this record supplies the separate scoped manual review. Final evidence-only changes do not change accepted application, scenario or CI source. Remote CI and merge/closure proof will be recorded in the pull request.

Android/iOS/native desktop builds, physical device/media QoE, the full historical conversation-files gate, and unrelated upload-queue acceptance: NOT_RUN in this Web-scoped task.
