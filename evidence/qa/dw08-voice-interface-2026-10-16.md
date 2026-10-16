# DW-008 / #347 — compact Web voice interface

**PASS for this Web UI leaf.** Tested source `aa959a2d72c474a5a96ec51f01445dabaacdaa5d`; base remote master `4cda8f5c464e006f1b3d7c65c2c16395656f3bab`. Detailed hashes, stage outcomes, screenshots and boundaries: [machine-readable evidence](dw08-voice-interface-2026-10-16.json).

The room and persistent dock now use the same primary control component and existing callbacks. Mute/deafen show distinct slash icons and persistent state; starting/stopping share has an explicit busy label/icon, active share has a stop glyph, and leave is distinct. All four actions stay available with the mobile drawer closed. PTT, denied permission, deafen-in-progress and connection transitions retain their guards. The short prejoin exposes «Войти» and «Без микрофона»; errors and unsupported-capture guidance remain actionable. Quality/ping/activation/help and sender diagnostics are secondary disclosures.

Room status is compact and truthful, including the short pending-active JOINING phase. Participant cards wrap names, display accessible mute/deafen/speaking/share states and use the existing volume/watch callbacks. LEAVING immediately removes interactive room/stream elements; ended sessions cannot render stale selected streams. An open voice participant popover closes when the room ceases to be available. Read-only prejoin roster information remains legitimate. LiveKit, capture/user activation, session/PTT/device handling, API contracts and server ACL are unchanged.

## Verification

- 1555 unit tests in 473 files PASS.
- 24 focused Chromium cases PASS: primary pointer/keyboard/touch actions, PTT/denied/reconnect/leave/busy/failed/unsupported states, stale selected stream/popover removal, progressive disclosure and focus return.
- 88 axe state scans: eleven states at 320/390/1024/1440 CSS px and 100%/200% root text. Actual Chromium page zoom 200% is separately measured at physical widths 640/780/2048/2880 (DPR/layout viewport/root font/pinch verified; no CSS zoom substitution).
- 11 responsive-shell cases PASS. The obsolete fixed 53px assertion was replaced with viewport-bottom anchoring and no main/composer overlap, preserving the original containment intent with four visible dock actions.
- Full source-bound local gate `.out/local-features/20261016-222648`: **22/22 stages PASS**, clean source/diff hash. Raw runner remains `REVIEW_REQUIRED`; the manual task review below completes this leaf's visual acceptance without changing the raw report or approving screenshot baselines.
- Actual owned HTTPS API/PostgreSQL/LiveKit/Tempo: desktop1440 and emulated touch393 PASS. Two real listener sessions, deafen controls, share setup cancellation with zero capture requests, focus return, TEXT/drawer/resize with the same WebRTC transports, and post-leave removal were checked. Cleanup was observed within **17 ms in each run**, a test observation, not a media/production SLO. Owned resources were removed.
- Specification traceability PASS: all 39 existing requirements referenced. Validation uses the committed requirement index; the approved Windows brief is unavailable on this host. No API contract change.

## Visual review

Fresh Before: 12 source-sized synthetic-state renders of exact base production files. Original private tour frames 30–32/43 were unavailable; this is a scenario comparison, not a claim to have reviewed that private pixel baseline.

After: **38 selected focused frames** from 102 generated captures were inspected at source resolution, plus **10 final actual-stack frames** through 20 unscaled crops. At final full-gate comparison, 37 selected frames were byte-identical; the one changed animated stopping-spinner frame was inspected again. The other 64 generated fixture frames have automated geometry/axe coverage, not a claim of individual manual review. Original dimensions and SHA256 are retained in JSON; screenshots/crops remain ignored local artifacts and the focused suite is retained by CI for 30 days.

Observed: shorter idle/joining surfaces; no repeated always-visible help or zero-screen count; consistent room/dock controls; visible red/slashed mute and deafen, dim disabled states and distinct active share. Large-text denied guidance no longer overlaps the channel subtitle. At 200% text the room scrolls while all four dock actions remain available; long room labels retain full accessible text/title. Expanded details, focus hints and transient touch highlights are explicitly represented, not treated as immutable reference pixels.

The actual touch post-leave capture retains the navigation drawer already opened by fault recovery. Its voice dock is absent; underlying prejoin and zero interactive old roster/stream elements are asserted independently. Unobscured prejoin and deliberately stale post-leave selection are also covered by the production-component fixture. The manual-leave reason retains its existing red notice styling. No persistent old-roster defect is inferred from the original tour's short-lived frame 43.

## Retained failures and corrections

Tests preceded implementation: the shared-state regression failed on base; the no-screen summary case also failed before its change. Mobile follow-up cases reproduced covered red paint and hidden closed-drawer actions. Expanded state scans found muted text contrast 4.47:1 and a missing role on a newly visible stream badge; the existing danger-text token and explicit image role correct them. Red edge tests caught a pending join claiming connection and loss of unsupported-capture guidance. These failures were not skipped or baseline-approved.

Clean candidate `da34ee00`: 22/22 local stages PASS, followed by additional visual findings. Clean candidate `30e60c90`: 21/22 PASS; the raw responsive-shell failure is retained. Both actual runtime widths passed on both candidates. Final `aa959a2d`: fresh 22/22 PASS, with all corrections and expanded tests. Only evidence files change after that accepted source; publication must verify this before merge.

## Scope boundaries

Native Android/iOS/macOS/Windows UI, physical microphone/system picker, physical screen readers, actual screen publication/game audio, QoE/capacity, production deployment and the original private-tour pixel baseline are **NOT_RUN here**. This Web leaf does not close their separate gates. No screenshot baseline was approved.
