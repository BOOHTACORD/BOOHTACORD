# DW-14 follow-up — wrapped DM draft at 200% text

Status: **FIXED; automated acceptance PASS; visual review remains REVIEW_REQUIRED**.

During source-resolution review for #353, the DM composer at 390×900 CSS px and 200% root text clipped the first line of a wrapped draft above the textarea. The pre-fix image is `390×900`, SHA-256 `5699550ec9a4878ff7d896c989b0e4f2067b6556a83b28d996bbf485da5f5422`. A focused Playwright assertion reproduced it: `scrollHeight=116`, `clientHeight=68`.

The shared Web composer now grows to show soft-wrapped input and caps at its CSS maximum with internal scrolling. Explicit Shift+Enter line breaks keep their prior fixed-height scrolling behavior. Draft state remains owned by the existing composer and survives TEXT/DM navigation. A later 1024px / 200% text review found a wrapped Cancel label and intraword wrapping in receiver diagnostics; Cancel now stays on one line, the diagnostics panel scales with rem-based text sizing, and fallback wrapping occurs only when a token cannot otherwise fit.

The after image is `390×900`, SHA-256 `3a4a17cf19751f6e1dcb48ac5f4f8fff875cb6790ffffcc259c856ba4b8acf19`. At source resolution both lines are visible, the send control remains inside the composer, and the pinned player and voice dock remain unobstructed. The before/after images are local QA artifacts and contain fixture conversation content; neither is copied into the repository.

Validation used working-tree source based on `4db4b0bb26ddc1a11847e6d95e3cbd88d7957f0e` (diff SHA-256 `c33962d96a7008291a4deefe9012bb3563027bedb7b9961681d8facf0e5e9c6a`); follow-up code commit 10b181af records these fixes.

- Focused mini-player browser suite: **19/19 PASS**.
- Existing composer scaling cases: **20/20 PASS** at 100%/200% text and widths 320–1440 px, including `Shift+Enter` scrolling.
- Registered Local Feature Acceptance: **28/28 stages PASS**, including 474 Web unit-test files / 1,571 tests, production build, 23 browser suites, and authenticated API/PostgreSQL/LiveKit journeys at 1440 px and 393 px. Command: `./tools/qa/local_features/check.sh --platform web --feature chat --feature shell --feature voice --feature screen --feature screen_track_name --base github/master --real-stack`.
- Focused search-tab suite: **16/16 PASS**, including measurement that the visible placeholder fits the search input at 320px and 200% text. The placeholder now reads “Поиск”.
- Raw report: `.out/local-features/20261017-191711/report.json`, SHA-256 `9dd54336481155b89eac463f02907b0b4e91d912f4f73cca2b13ab7fd03587af` (337,539 bytes). Its machine status is REVIEW_REQUIRED: 1,053 captures / 996 unique images. Sixteen current-run images were inspected at source resolution and 118 earlier reviews were reused only for exact SHA-256 matches; 862 unique images remain unreviewed. [Sixteen current-run source-resolution observations](dw14-composer-wrap-regression-2026-10-17.json) document the fixed 1024px/200% screen-share layout. No screenshot baseline was approved.

The current review set covers the 390px/200% DM draft; 320px search at 100%/200% text; authenticated desktop/mobile mini-player and screen-share statistics; narrow DM history and navigation; and screen-share setup, receiver statistics and diagnostics at 320px and 1024px with 200% root text. The source-resolution JSON companion records image paths, dimensions, hashes and observations.

Physical Chrome capture-picker, hardware audio, media QoE/capacity, and the #305 release review remain NOT_RUN / NO-GO. The user said the UX measurements and owner exist, but their values and identity are not available in auditable evidence; this UI fix does not close that release gate.
