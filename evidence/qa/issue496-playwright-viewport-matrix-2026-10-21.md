# Issue #496: Playwright viewport matrix reduction

**Date:** 2026-10-21
**Backlog leaf:** DW-015
**Result:** local browser-suite measurement PASS; post-change GitHub Actions verification PENDING

## Scope

Reduced repeat combinations in five Web Playwright suites using functional, edge, breakpoint, short-height and actual browser-zoom samples. No application UI, CSS, reference catalog, screenshot baseline or CI workflow was changed. This work does not claim visual-regression approval: it changes runtime captures and does not update or bless golden images.

The mandatory UIUX-2026 set stays `320x640`, `390x844`, `768x1024`, `1024x768`, `1440x900` and `1920x1080`. The full responsive-shell sweep remains intact. Focused samples retain adjacent `1024`/`1280` breakpoints, short heights, 200% text, actual browser zoom, keyboard/ARIA/WCAG checks, touch PTT, sender/receiver screen-share disclosures and critical voice states.

## Local before/after measurement

Each side was run twice, sequentially, on the same Mac host and Chromium setup. Durations below are Playwright-reported suite durations averaged over both runs; they exclude process startup. PNG totals count screenshots emitted by the five suites and sum their file sizes.

| Suite | Tests before → after | Mean Playwright seconds before → after | PNGs before → after | PNG bytes before → after |
| --- | ---: | ---: | ---: | ---: |
| Controls | 87 → 26 | 46.4 → 12.4 | 105 → 12 | 10,310,806 → 1,667,123 |
| Screen share UI | 31 → 23 | 27.9 → 18.4 | 90 → 26 | 5,950,630 → 1,431,745 |
| Voice interface | 36 → 26 | 21.7 → 13.6 | 132 → 30 | 5,991,970 → 1,246,586 |
| Navigation density | 28 → 25 | 10.2 → 8.9 | 26 → 14 | 1,592,766 → 940,576 |
| Responsive shell | 26 → 19 | 11.0 → 6.8 | 13 → 13 | 314,724 → 314,724 |
| **Total** | **208 → 119 (-42.8%)** | **117.1 → 60.0 (-48.8%)** | **366 → 95 (-74.0%)** | **24,160,895 → 5,600,754 (-76.8%)** |

The two post-change runs passed all five suites. Raw run times, in suite order above, were `12.5/12.3`, `18.3/18.4`, `13.5/13.6`, `8.9/8.9` and `6.8/6.8` seconds. Total PNG counts and bytes were `95 / 5,600,793` and `95 / 5,600,714`.

Environment: macOS 26.6.1 arm64, Node 24.14.0, npm 11.9.0, Playwright 1.63.0, Python 3.14.4, Chromium. Local fixture servers required loopback access. The browser checks used the repository's local deterministic fixtures and no live media service.

## Coverage and risk selection

| Area | Kept coverage | Matrix reduction |
| --- | --- | --- |
| Controls | Five surfaces at 100% and 200% text; selected required viewport and actual-zoom checks; 320x568 audio text stress; keyboard, touch and axe assertions | Removed repeated surface × width × scale Cartesian combinations |
| Screen share | All five disclosure states in the main desktop sample; selected responsive states at every required viewport and breakpoint boundary; sender/receiver disclosure assertions and axe checks | Replaced eight width/scale cases each repeating all five states with a desktop state sweep and a focused responsive sample |
| Voice | All eleven states at the main desktop size; critical states across required sizes and boundaries; dedicated touch PTT, participant-card, keyboard, axe and actual-zoom cases | Replaced eleven states repeated across ten viewport/scale combinations with a state sweep plus targeted responsive states |
| Navigation | Geometry/state checks across all six mandatory viewport sizes; edge and breakpoint resize behavior; retained short-height coverage | Captures only at representative 390px and 1440px sizes; short-height cases reduced to representative layout classes |
| Responsive shell | Full existing 12-entry shell viewport sweep and all six mandatory-size screenshots; exact and adjacent breakpoint widths; short-height coverage | Kept full shell sweep; narrowed repeated favorite-row scenarios to representative layout classes |

`ux2026RequiredViewports` and `ux2026ShellViewports` were not reduced. New shared arrays make functional, edge, breakpoint, short-height and true browser-zoom samples explicit and test their values. Actual zoom uses physical `640px` and `2880px` widths to represent CSS widths `320px` and `1440px` at 200% zoom.

## CI reference and remaining verification

The prior GitHub Actions reference is [run 39459009233](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39459009233), associated with PR #453 and reported as 26 passing CI jobs. Its full job elapsed times were about 9m06s for `browser-shell`, 6m48s for `browser-content` and 15m31s for `browser-voice`, including setup and artifact upload. These CI job times are a reference only; they are not compared as if they were local suite durations.

Post-change GitHub Actions profile durations and `ci-required` result: **PENDING**. Initial code-change [PR run 39501253259](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39501253259) passed the `changes` classifier but its queued `contracts` and browser jobs were cancelled after a documentation-only follow-up push superseded the commit. The follow-up [PR run 39502321662](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39502321662) was pending with no jobs listed at the time of this report. Neither run produced profile durations or a `ci-required` result, so this CI evidence remains **NOT_RUN** and cannot close a gate. The approved Windows product brief was unavailable on this Mac; the required traceability checker validated the committed requirement index and reported that limitation.

## Verification completed locally

- Five affected Playwright suites passed twice after the matrix change.
- `npm test` passed: 478 files, 1,594 tests.
- `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru npm run build` passed (existing chunk-size and dynamic-import warnings remain).
- `pwsh -NoProfile -File tools/verify/spec_traceability/verify-spec-traceability.ps1` passed against the committed requirement index: 39 requirements referenced.
- `git diff --check` passed.
