# DW-14 / #353 — current-master Web regression acceptance

Result: **PASS for the explicitly selected Web regression baseline, with the exceptions below.** This receipt supersedes the earlier DW-14 progress records. It does not approve physical media or release gate #305.

The user confirmed on 17 October that `web-tour-2026-10-15.zip` no longer exists. Its 55-row historical state/owner inventory is retained as **unverified metadata**, not reviewed source pixels. No original account/DM image is recovered or published. The replacement is built from exact current master `43d0c491575f83f03d72bb7355392ce82f56d998` and the tested source below, using controlled data. Missing historical pixels are an explicit source-loss exception, not a PASS.

## Code and regressions

The PR debounces brief receiver audio-presence changes, moves the share-start notice into workspace flow, makes voluntary voice leave neutral, retains error treatment for server revocation, and fixes narrow search/audio/control presentation. Two additional reproductions were fixed in this pass: soft-wrapped drafts did not follow conversation-only width changes; enlarged advanced-audio text extended beyond its card. Focused failing tests preceded both fixes. The composer grows/shrinks while retaining the draft and caps at its existing maximum; explicit Shift+Enter behaviour remains unchanged.

The integrated screen-share follow-up keeps Cancel on one line and makes desktop statistics readable at 200% text. Selected profile, sender confirmation and measured/stale receiver values remain distinct. No media quality/capacity claim is made.

One transient draft screenshot was rejected: it preceded the resize-observer frame although subsequent behaviour assertions passed. Capture now follows the unchanged height/content assertions; the mini-player suite passed 20/20. No transient frame is an approved reference.

## Validation and baseline

- Clean runtime source: `b659092fc18f223b125642026b37f45a14517bab`; Web source tree `3b2b7b65f3cc6741bd1d6b55a75f53780d67a1c7`, scenario tree `4f1e8aebfe425e5b7d32852c3db012fccc789ce9`. Published production must match that source tree. A later failure-only diagnostic test overlay is described below; its scenario tree is independently verified. Local runtime commit identifiers are provenance; immutable published-head/CI links are added to PR #368.
- Registered command: `./tools/qa/local_features/check.sh --platform web --feature chat --feature shell --feature voice --feature screen --feature screen_track_name --base 43d0c491575f83f03d72bb7355392ce82f56d998 --real-stack`.
- **28/28 stages PASS:** 474 unit-test files / 1,571 tests, production typecheck/build, all 24 browser suites and authenticated API/PostgreSQL/LiveKit/Tempo journeys at desktop 1440px and touch 393px. Local runner resolves Node 26 via Homebrew; focused runs use Node 24. Final CI independently uses the locked Node version.
- CSS widths 320/390/768/1024/1440/1920/3440, 100/200% root text, independently measured actual browser zoom 200%, keyboard and touch are asserted by the registered suites.
- Raw report `.out/local-features/20261017-214952/report.json`: SHA-256 `17ade13237713b57e86b26a94782435dda888599ac2770d029806d1506965869`, 1,062 captures / 999 unique. Its global status stays `REVIEW_REQUIRED`; unselected images are not visually approved.
- Replacement `web-regression-v3`: **46 selected captures reviewed**, 44 unique images. Only declared lossless modal regions are selected for wide DM overlays. Tall audio is inspected in overlapping original-pixel slices; reused reviews require exact image hashes. Baseline report SHA-256 `112914ceeffe7432cf37c9f34088955085ec17c9da46f687bc5b8bf19e4eae9e` at `.out/issue353/baselines/web-regression-v3`. The JSON companion lists every source/crop, dimensions, hashes and observation.

Before/after uses production source and contract data exported from the same current master with the fixture scenarios frozen in receipt v1 (before the two wider-font cases were added). Before: controls 81/83 (two audio label/value overlaps), DM picker 22/24 (two 36px coarse-pointer actions), search 26/26. After: all corresponding suites pass. Failed before captures remain comparisons, not approved references. The first incomplete snapshot lacked a contract catalog; it was stopped and restored before comparison, with its failed setup log retained.

Earlier full 27-stage runs are retained: `20261017-190615` passed commands but revealed the audio-card defect visually; `20261017-192437` passed commands but included the transient draft capture. The expanded selection initially rejected a missing `screen_track_name` registration target before tests started; the accepted run includes it. An older Linux frontend job saw a 26px DM-prepend drift; an earlier candidate passed 20 local repetitions without relaxing the 2px assertion, but this did not resolve the Linux failure; the pagination fix below addresses it. Final exact-head CI is required before merge.

## Final CI defect and additional before/after

The earlier published head `1a8d8708` failed Linux frontend job `117453712294`: the microphone caption extended beyond its activation card at 320px/200% text. This was fixed rather than waived. A wider-font reproduction (monospace plus 0.12em letter spacing) failed before the change. Source-pixel review then identified range/meter/selector boxes outside the padding, and four additional geometry assertions failed before that fix. The sensitivity grid and activation track now use constrained columns; native range margins are removed. **All four normal/wider-font cases pass** with unchanged text and padding bounds. Long words may wrap at 320px/200% text; they remain readable and selectable without horizontal clipping.

Navigation follow-up `8dccb58f` is integrated: hints cannot intercept adjacent channel clicks, Quick Jump uses a fully fitting “Поиск” placeholder and retains its full accessible label. Its new behavior tests, all 24 browser suites (691 cases) and the owned real-stack desktop/touch journeys pass on the clean source above. The intervening `20261017-204256` run is retained as automation-pass/visual-fail, not an approved baseline; its tests were subsequently extended after the corresponding suite had finished.

All **46 selected captures** have source-resolution observations or exact-hash reuse. The changed tall audio images were viewed in overlapping 3500px slices; the JSON records each source/crop/review. This selected replacement supersedes v1, whose immutable receipt remains at `1a8d8708`. Unselected raw images remain unapproved, and #305/#303 remain separate gates. Source-tour loss is an explicit exception confirmed by the user. Scope for #353 is the reproducible Web regression baseline and its named exceptions, not approval of every diagnostic screenshot emitted by the runner.

## DM pagination integration

Linux job `117466229045` passed the microphone/card checks but repeated the original 26px DM-prepend drift. The integrated `18e87bad` change disables automatic browser scroll anchoring for the DM list, where the application already restores pagination position; TEXT virtualization remains unchanged. A separate held-response regression also reproduced a 26px movement while the pagination label changed height (78px ready versus 52px loading). Both captions now share a reserved grid track, preserving flow height, current accessible name, disabled state and `aria-busy`. The original 2px limit remains unchanged; waiting for both ready/loading captions and reaction completion strengthens the test. Native-anchoring suppression alone failed with 650px drift and was not accepted without the row-size observer.

The new regression checks position **before, during and after** the held response; all four 320×900 original-pixel captures are included in the selected baseline. The original message stays fixed while older content appears above it; header and composer remain separate. Controlled caption width/font is explicitly synthetic and not claimed as default production typography. The strengthened completion test also waits for delayed reaction responses, checks user-scroll handoff and a later attachment expansion, and verifies bottom-follow on a new message. A border-box ResizeObserver now retains the chosen row through those later size changes. All 54 chat cases additionally pass in a Linux/arm64 container (Playwright 1.63.0, Node 24.20.0), with matching source overlay hashes and four reviewed original-pixel captures recorded in the JSON. Both focused integrated cases and the full 24-suite Mac run pass. This identifies two interacting pagination concerns; the loading-label reproduction is not presented as proof that it alone caused the Linux after-response failure.

An initial component-scoped style addition failed one existing design-system contract. The rejected run was stopped before actual-stack work; rules now live in shared `conversation.css`, all 9 focused contract tests pass, and the clean integrated source above passed all 28 stages. The final baseline contains **46 selected captures**, including the four pagination states; earlier v1/v2 receipts remain immutable historical evidence. Exact final published-head CI is still required before merge.

A subsequent `6d68c8a3` proposal delayed restoration by two animation frames. A Linux variant with that same wait and stable captions still drifted 650px when held reactions were released later. Its commit is retained in ancestry; the final implementation keeps the verified resize-driven restoration. The final production/scenario trees remain exactly equal to the accepted hashes.

## Failure-reporting overlay

After the clean 28-stage run, retained commit `474b649c` added only geometry logging inside the existing failed-assertion catch path. The successful assertion path is byte-for-byte equivalent after removing that wrapper. Production source is unchanged. The final scenario tree is `23b4f16a74e5c4bf831bb6f841ec3df2e76b2b9f`; all 54 chat cases passed again on both Mac and Linux for local integration `0e3b79d4cb55401ac8728028d42f71c75f0500dc`. The JSON keeps the full-gate scenario tree and this later overlay separate. Exact published-head CI is required before merge.

## Tasks and child issues

| Children | Current scenario / evidence |
| --- | --- |
| #340 / #341 / #342 | Search modes/query/focus, top-layer DM picker/cancel/pagination/touch, shared controls and enlarged audio forms; same-master comparisons above. |
| #343 / #344 / #345 | Microcopy, navigation density, message actions/draft/IME/scroll-anchor assertions; actual channel/DM journeys. |
| #346 | Pins, archive, files, mentions, quick jump and return-to-message context on the owned stack. |
| #347 / #348 / #349 | Voice join/leave/revocation and synthetic SFU sender/receiver/mini-player continuity. Hardware/media-quality exceptions remain NOT_RUN. |
| #350 / #351 / #352 | Member profile/ACL, settings/forms and context headers; immutable DW-11/12/13 receipts plus the current unit/browser/actual-stack scenarios. |
| #353 | This current-source receipt and the 46-image selected replacement baseline. |
| #354 | Explicit exception: optional compact mode deferred pending demonstrated usability need. |

The JSON contains the complete issue → PR → commit → evidence crosswalk. The original tour frame numbering is not promoted to verified current-source evidence.

## Release review and exceptions

Review of [#305](https://github.com/BOOHTACORD/BOOHTACORD/issues/305) and [the release protocol](../../docs/design/UIUX_2026_RELEASE_GATE.md) records **NO-GO / NOT_RUN** for release acceptance: real-user baseline/post-change measurements, sample size and named Web rollback owner remain absent. Automated task scripts are not user completion/time/error/backtracking measurements. This regression acceptance closes none of those release gates; retain the prior immutable Web artifact/revert-and-rebuild rollback path and complete cohort/owner approval separately.

Supported-Chrome system picker, physical microphone/system audio, dynamic video, media QoE/capacity and 1080p60 remain **NOT_RUN**, as explicitly permitted for named smoke gaps in #353. Synthetic canvas/audio and static decoded frames do not prove those capabilities. Original-tour comparison is **EXCEPTION_SOURCE_LOST** after the user's confirmation; current-master reproducibility replaces the lost pixels. There are no known P0/P1 blockers in the executed Web regression scope.

Spec traceability: 39 requirements, **PASS_INDEX_ONLY** because the approved Windows brief is unavailable on this Mac. API/schema contracts are unchanged. No generated images, credentials or original conversation content are staged.

Machine-readable receipt: [JSON](dw14-final-acceptance-2026-10-17.json).
