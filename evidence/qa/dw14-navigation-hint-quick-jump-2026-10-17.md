# DW-14 follow-up — navigation hint hit testing and Quick Jump placeholder

Status: **code and focused browser suites PASS; full release visual review remains REVIEW_REQUIRED**.

The local navigation lifecycle exposed two Web issues while reviewing #353. At 1440px, an action hint could cover the next channel row and receive the click intended for that row. A new behavior test reproduced the problem before the fix: clicking the center of the covered row did not set its `aria-current` state. Navigation hints now ignore pointer hit testing while keeping their visible text and `aria-describedby` relationship; the same test passes and the other surfaces retain hoverable hints.

Quick Jump's Russian placeholder was wider than the input at 320px with 200% root text. The browser measured 360.1875px of placeholder text against a 261px input content box. The visible text is now “Поиск”; a visually hidden label retains the full accessible name “Найти канал или человека”. The focused regression checks both the accessible name and measured fit.

The source-resolution before/after captures are local, ignored QA artifacts at 320×1000 CSS/source pixels. Before SHA-256: `06a7b78a385a3cbb11e65fd0e8413aad7f7052c5ce1880c1f25461d3c01de714`; after SHA-256: `37cedebe837c2992267805e1034101eb1d923f8a30bc0b0b702cd137709fcb70`. The old placeholder visibly truncates after “Канал или имя ч…”; “Поиск” fits in full. The participant “Показать ещё участников” action wraps to two lines but remains within the viewport.

Validation on the working tree:

- Navigation density browser suite: **26/26 PASS**, including the new pointer hit-test regression.
- Microcopy/action-hint browser suite: **60/60 PASS**, including tooltip hover, focus and dismissal behavior.
- Search presentation browser suite: **106/106 PASS**.
- Search session browser suite: **26/26 PASS**.
- Production Web typecheck/build: **PASS** with the CI public origin `https://v.bootybay.ru`.
- The click regression failed before the CSS change and passed afterward. `git diff --check` is clean.

The registered Web acceptance also passed on exact PR source `8dccb58fa754f3b3fe0fb27bf3dd485ff06612e3` (clean tree): **28/28 automated stages**, including 474 unit-test files / 1,571 tests, 24 browser suites / 688 cases, production build, and authenticated API/PostgreSQL/LiveKit/Tempo journeys at desktop 1440px and touch 393px. Raw report `.out/local-features/20261017-202636/report.json` is 338,594 bytes with SHA-256 `12b3567254391fcd91036cca1bfa9574c5651ea8c3fed00931c560aeb4a6c615`. The report remains `REVIEW_REQUIRED`: it contains 1,056 captures / 997 unique images. Nine current-run captures were inspected at source resolution; 136 previous reviews were reused only on exact SHA-256 matches, giving 143 reviewed unique images and 854 still unreviewed. No new screenshot baseline was approved.

Current-run visual observations: the 320×1000 / 200% Quick Jump capture shows the full “Поиск” placeholder and focus ring; desktop and mobile real-stack Quick Jump results fit their panels. At 320px navigation, long names ellipsize inside rows while action buttons, connected voice dock and profile footer remain visible; at 1440px the channel list stays within its sidebar. The 393px navigation drawer keeps its search, channel rows and profile footer reachable. The desktop VoiceLab view preserves the text conversation, member rail and connected voice controls. Screen-share statistics stay inside the desktop viewer and mobile sheet; source confirmation and receiver values remain separately labelled, with unknown FPS shown as unknown. Paths, source dimensions and hashes for these nine images are in the companion JSON; generated captures remain ignored local files.

This evidence covers focused browser behavior, the Quick Jump before/after pair and nine selected captures from the registered run. It does not close #305: UX task measurements and the named Web rollback owner must be present in auditable release evidence; the gate remains **NO-GO / NOT_RUN**. It also does not close the #353 source-tour review while 854 unique images remain unreviewed.

Capture files are in `.out/dw14-quick-jump-placeholder/` and are not committed because they contain fixture content. The before/after source hashes and observations are recorded in the companion JSON.
