# DW-14 follow-up — wrapped DM draft at 200% text

Status: **FIXED; automated acceptance PASS; visual review remains REVIEW_REQUIRED**.

During source-resolution review for #353, the DM composer at 390×900 CSS px and 200% root text clipped the first line of a wrapped draft above the textarea. The pre-fix image is `390×900`, SHA-256 `5699550ec9a4878ff7d896c989b0e4f2067b6556a83b28d996bbf485da5f5422`. A focused Playwright assertion reproduced it: `scrollHeight=116`, `clientHeight=68`.

The shared Web composer now grows to show soft-wrapped input and caps at its CSS maximum with internal scrolling. Explicit `Shift+Enter` line breaks keep their prior fixed-height scrolling behavior. Draft state remains owned by the existing composer and survives TEXT/DM navigation.

The after image is `390×900`, SHA-256 `3a4a17cf19751f6e1dcb48ac5f4f8fff875cb6790ffffcc259c856ba4b8acf19`. At source resolution both lines are visible, the send control remains inside the composer, and the pinned player and voice dock remain unobstructed. The before/after images are local QA artifacts and contain fixture conversation content; neither is copied into the repository.

Validation on final working-tree source (`ad71c5c9205fbd6c58c786475bc19afd7e6a5501`, diff SHA-256 `67e4d851cce0f3921542c6256d7144c4b6e4c5a8d9569fe838f2d08ae49b3dad`):

- Focused mini-player browser suite: **19/19 PASS**.
- Existing composer scaling cases: **20/20 PASS** at 100%/200% text and widths 320–1440 px, including `Shift+Enter` scrolling.
- Registered Local Feature Acceptance: **27/27 stages PASS**, including 474 Web unit-test files / 1,571 tests, production build, 23 browser suites, and authenticated API/PostgreSQL/LiveKit journeys at 1440 px and 393 px. Command: `./tools/qa/local_features/check.sh --platform web --feature chat --feature shell --feature voice --feature screen --base github/master --real-stack`.
- Raw report: `.out/local-features/20261017-180122/report.json`, SHA-256 `bb06b9a15c69fb628461549bf345ea0637e8dc20a4d01ef236d3102203fe16b8` (336,744 bytes). Its machine status is `REVIEW_REQUIRED`: 1,051 captures / 995 unique images. This follow-up directly reviewed 10 current-run images at source resolution and reused 20 earlier reviews whose SHA-256 exactly matches current-run files; 965 unique images remain unreviewed. No screenshot baseline was approved.

The current review set covers the 390px/200% DM draft; authenticated desktop/mobile mini-player, voice-after-leave and screen-share statistics; and narrow 320px DM conversation, navigation and archive. Both mini-player viewports retain the DM and visible composer; the notice stays between the player and conversation header; voice leave is neutral; selected, confirmed and measured screen-share values remain distinct; narrow chat, navigation and archive controls fit or scroll within their owners. The JSON companion records each path, dimension, hash and observation.

Physical Chrome capture-picker, hardware audio, media QoE/capacity, and the #305 release review remain **NOT_RUN / NO-GO**. The needed task measurements and named Web rollback owner are not recorded in the available evidence, so this UI fix does not close the release gate.
