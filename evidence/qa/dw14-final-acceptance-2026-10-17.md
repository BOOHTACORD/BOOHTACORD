# DW-14 / #353 — current-master Web regression acceptance

Result: **PASS for the explicitly selected Web regression baseline, with the exceptions below.** This receipt supersedes the earlier DW-14 progress records. It does not approve physical media or release gate #305.

The user confirmed on 17 October that `web-tour-2026-10-15.zip` no longer exists. Its 55-row historical state/owner inventory is retained as **unverified metadata**, not reviewed source pixels. No original account/DM image is recovered or published. The replacement is built from exact current master `43d0c491575f83f03d72bb7355392ce82f56d998` and the tested source below, using controlled data. Missing historical pixels are an explicit source-loss exception, not a PASS.

## Code and regressions

The PR debounces brief receiver audio-presence changes, moves the share-start notice into workspace flow, makes voluntary voice leave neutral, retains error treatment for server revocation, and fixes narrow search/audio/control presentation. Two additional reproductions were fixed in this pass: soft-wrapped drafts did not follow conversation-only width changes; enlarged advanced-audio text extended beyond its card. Focused failing tests preceded both fixes. The composer grows/shrinks while retaining the draft and caps at its existing maximum; explicit Shift+Enter behaviour remains unchanged.

The integrated screen-share follow-up keeps Cancel on one line and makes desktop statistics readable at 200% text. Selected profile, sender confirmation and measured/stale receiver values remain distinct. No media quality/capacity claim is made.

One transient draft screenshot was rejected: it preceded the resize-observer frame although subsequent behaviour assertions passed. Capture now follows the unchanged height/content assertions; the mini-player suite passed 20/20. No transient frame is an approved reference.

## Validation and baseline

- Clean runtime source: `7f8f1b6a41928085b999a1bd98601b6927e08607`; Web source tree `47f8ed52c7a553cc4c82ffcc3bd2673128e876cc`, scenario tree `0a04d7809a87d1b34dabe5b5c8cdd49cc831f335`. Published and merged trees must match these source/scenario trees. Local runtime commit identifiers are provenance; immutable published-head/CI links are added to PR #368.
- Registered command: `./tools/qa/local_features/check.sh --platform web --feature chat --feature shell --feature voice --feature screen --feature screen_track_name --base 43d0c491575f83f03d72bb7355392ce82f56d998 --real-stack`.
- **28/28 stages PASS:** 474 unit-test files / 1,571 tests, production typecheck/build, all 24 browser suites and authenticated API/PostgreSQL/LiveKit/Tempo journeys at desktop 1440px and touch 393px. Local runner resolves Node 26 via Homebrew; focused runs use Node 24. Final CI independently uses the locked Node version.
- CSS widths 320/390/768/1024/1440/1920/3440, 100/200% root text, independently measured actual browser zoom 200%, keyboard and touch are asserted by the registered suites.
- Raw report `.out/local-features/20261017-205335/report.json`: SHA-256 `3bf2ead9b2e23e817ccf9f8734c4710c1fe72b863da2a6b23528fffa3b4a864e`, 1,058 captures / 1,001 unique. Its global status stays `REVIEW_REQUIRED`; unselected images are not visually approved.
- Replacement `web-regression-v2`: **42 selected captures reviewed**, 40 unique images. Only declared lossless modal regions are selected for wide DM overlays. Tall audio is inspected in overlapping original-pixel slices; reused reviews require exact image hashes. Baseline report SHA-256 `162518bc780ce765cf16dd417187cfecc9ee6e73debb44671b65aae5621aaa30` at `.out/issue353/baselines/web-regression-v2`. The JSON companion lists every source/crop, dimensions, hashes and observation.

Before/after uses production source and contract data exported from the same current master with the fixture scenarios frozen in receipt v1 (before the two wider-font cases were added). Before: controls 81/83 (two audio label/value overlaps), DM picker 22/24 (two 36px coarse-pointer actions), search 26/26. After: all corresponding suites pass. Failed before captures remain comparisons, not approved references. The first incomplete snapshot lacked a contract catalog; it was stopped and restored before comparison, with its failed setup log retained.

Earlier full 27-stage runs are retained: `20261017-190615` passed commands but revealed the audio-card defect visually; `20261017-192437` passed commands but included the transient draft capture. The expanded selection initially rejected a missing `screen_track_name` registration target before tests started; the accepted run includes it. An older Linux frontend job saw a 26px DM-prepend drift; this candidate passed 20 local repetitions without relaxing the 2px assertion. Final exact-head CI is required before merge.

## Final CI defect and additional before/after

The earlier published head `1a8d8708` failed Linux frontend job `117453712294`: the microphone caption extended beyond its activation card at 320px/200% text. This was fixed rather than waived. A wider-font reproduction (monospace plus 0.12em letter spacing) failed before the change. Source-pixel review then identified range/meter/selector boxes outside the padding, and four additional geometry assertions failed before that fix. The sensitivity grid and activation track now use constrained columns; native range margins are removed. **All four normal/wider-font cases pass** with unchanged text and padding bounds. Long words may wrap at 320px/200% text; they remain readable and selectable without horizontal clipping.

Navigation follow-up `8dccb58f` is integrated: hints cannot intercept adjacent channel clicks, Quick Jump uses a fully fitting “Поиск” placeholder and retains its full accessible label. Its new behavior tests, all 24 browser suites (690 cases) and the owned real-stack desktop/touch journeys pass on the clean source above. The intervening `20261017-204256` run is retained as automation-pass/visual-fail, not an approved baseline; its tests were subsequently extended after the corresponding suite had finished.

All **42 selected captures** have source-resolution observations or exact-hash reuse. The changed tall audio images were viewed in overlapping 3500px slices; the JSON records each source/crop/review. This selected replacement supersedes v1, whose immutable receipt remains at `1a8d8708`. Unselected raw images remain unapproved, and #305/#303 remain separate gates. Source-tour loss is an explicit exception confirmed by the user. Scope for #353 is the reproducible Web regression baseline and its named exceptions, not approval of every diagnostic screenshot emitted by the runner.

## Tasks and child issues

| Children | Current scenario / evidence |
| --- | --- |
| #340 / #341 / #342 | Search modes/query/focus, top-layer DM picker/cancel/pagination/touch, shared controls and enlarged audio forms; same-master comparisons above. |
| #343 / #344 / #345 | Microcopy, navigation density, message actions/draft/IME/scroll-anchor assertions; actual channel/DM journeys. |
| #346 | Pins, archive, files, mentions, quick jump and return-to-message context on the owned stack. |
| #347 / #348 / #349 | Voice join/leave/revocation and synthetic SFU sender/receiver/mini-player continuity. Hardware/media-quality exceptions remain NOT_RUN. |
| #350 / #351 / #352 | Member profile/ACL, settings/forms and context headers; immutable DW-11/12/13 receipts plus the current unit/browser/actual-stack scenarios. |
| #353 | This current-source receipt and the 42-image selected replacement baseline. |
| #354 | Explicit exception: optional compact mode deferred pending demonstrated usability need. |

The JSON contains the complete issue → PR → commit → evidence crosswalk. The original tour frame numbering is not promoted to verified current-source evidence.

## Release review and exceptions

Review of [#305](https://github.com/Egkurilov/BOOHTACORD/issues/305) and [the release protocol](../../docs/design/UIUX_2026_RELEASE_GATE.md) records **NO-GO / NOT_RUN** for release acceptance: real-user baseline/post-change measurements, sample size and named Web rollback owner remain absent. Automated task scripts are not user completion/time/error/backtracking measurements. This regression acceptance closes none of those release gates; retain the prior immutable Web artifact/revert-and-rebuild rollback path and complete cohort/owner approval separately.

Supported-Chrome system picker, physical microphone/system audio, dynamic video, media QoE/capacity and 1080p60 remain **NOT_RUN**, as explicitly permitted for named smoke gaps in #353. Synthetic canvas/audio and static decoded frames do not prove those capabilities. Original-tour comparison is **EXCEPTION_SOURCE_LOST** after the user's confirmation; current-master reproducibility replaces the lost pixels. There are no known P0/P1 blockers in the executed Web regression scope.

Spec traceability: 39 requirements, **PASS_INDEX_ONLY** because the approved Windows brief is unavailable on this Mac. API/schema contracts are unchanged. No generated images, credentials or original conversation content are staged.

Machine-readable receipt: [JSON](dw14-final-acceptance-2026-10-17.json).
