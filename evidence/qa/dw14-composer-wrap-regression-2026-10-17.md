# DW-14 follow-up — wrapped DM draft at 200% text

Status: **FIXED; automated acceptance PASS; visual review remains REVIEW_REQUIRED**.

During source-resolution review for #353, the DM composer at 390×900 CSS px and 200% root text clipped the first line of a wrapped draft above the textarea. The pre-fix image is `390×900`, SHA-256 `5699550ec9a4878ff7d896c989b0e4f2067b6556a83b28d996bbf485da5f5422`. A focused Playwright assertion reproduced it: `scrollHeight=116`, `clientHeight=68`.

The shared Web composer now grows to show soft-wrapped input and caps at its CSS maximum with internal scrolling. Explicit `Shift+Enter` line breaks keep their prior fixed-height scrolling behavior. Draft state remains owned by the existing composer and survives TEXT/DM navigation.

The after image is `390×900`, SHA-256 `3a4a17cf19751f6e1dcb48ac5f4f8fff875cb6790ffffcc259c856ba4b8acf19`. At source resolution both lines are visible, the send control remains inside the composer, and the pinned player and voice dock remain unobstructed. The before/after images are local QA artifacts and contain fixture conversation content; neither is copied into the repository.

Validation used working-tree source based on `ef842e6210020709423a64aa2be315d96c33208a` (diff SHA-256 `4da0093b3239ac60697d67b5056c14388ff39ed138639788344b39fe36161ff3`); code and tests are recorded in follow-up commit `96fffa3c`:

- Focused mini-player browser suite: **19/19 PASS**.
- Existing composer scaling cases: **20/20 PASS** at 100%/200% text and widths 320–1440 px, including `Shift+Enter` scrolling.
- Registered Local Feature Acceptance: **27/27 stages PASS**, including 474 Web unit-test files / 1,571 tests, production build, 23 browser suites, and authenticated API/PostgreSQL/LiveKit journeys at 1440 px and 393 px. Command: `./tools/qa/local_features/check.sh --platform web --feature chat --feature shell --feature voice --feature screen --base github/master --real-stack`.
- Focused search-tab suite: **16/16 PASS**, including measurement that the visible placeholder fits the search input at 320px and 200% text. The placeholder now reads “Поиск”.
- Raw report: `.out/local-features/20261017-183225/report.json`, SHA-256 `979c15b0ae54fd72c832bc9f92b51aaa8563d27030d8a2fae26641816c6f5d66` (336,744 bytes). Its machine status is `REVIEW_REQUIRED`: 1,051 captures / 994 unique images. Seventeen current-run images were inspected at source resolution and 104 earlier reviews were reused only for exact SHA-256 matches; 73 additional matches came from source-resolution manual review records in runs 20261017-140223, 20261017-141612 and 20261017-145030. 873 unique images remain unreviewed. [Eight additional source-resolution observations](dw14-composer-wrap-regression-2026-10-17.json) cover the 390px/200% DM starter, search results, voice controls, screen-share diagnostics, mini-player composer, member roster, compact header and 768px navigation. No screenshot baseline was approved.

The current review set covers the 390px/200% DM draft; 320px search at 100%/200% text; authenticated desktop/mobile mini-player, desktop voice-after-leave and screen-share statistics; and narrow 320px DM conversation and navigation. The search placeholder is fully visible at both text sizes; the mini-player and composer remain visible; the share notice occupies its own row; voice leave is neutral; selected, confirmed and measured screen-share values remain distinct; narrow chat content wraps and navigation scroll stays within its rail. The JSON companion records each path, dimension, hash and observation.

Physical Chrome capture-picker, hardware audio, media QoE/capacity, and the #305 release review remain **NOT_RUN / NO-GO**. The needed task measurements and named Web rollback owner are not recorded in the available evidence, so this UI fix does not close the release gate.
