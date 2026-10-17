# DW-011 / #350 — member roster and contextual profile

Date: 2026-10-17, Europe/Istanbul. Parent #339. Web only.
Base master `9dc3159220349fb3872ba08fbca8b9e6a76adc73`; accepted clean local source `ccc5ce515033ee4675903385d9afe31a7acdf70c`.
Dependencies: T-050, T-014, T-020, T-022, DW-003, DW-005 and DW-010.

Rows now show avatar/name with grouped, named presence or the existing voice
state icon, without repeating prose. Names ellipsize in the row and retain a
full title/accessibility label. Profiles retain complete wrapping identity,
login, role, status, DM and applicable voice volume/admin controls. Individual
volume and server ACL APIs are unchanged. The one existing members drawer is
reused, including narrow desktop; its desktop voice backdrop now covers the
viewport instead of occupying an incidental grid column.

The compact fixed card follows its trigger, flips/shrinks around headers,
composer, voice controls and mini-player, and scrolls internally when necessary.
Keyboard focus wraps in modal mode; Escape closes the profile before the outer
drawer and returns focus. Outside dismissal respects the clicked control.
Retry is a themed 44px target and restores focus after its loading replacement
without stealing focus after close/unmount or navigation outside the card.

## Verification

- 1564 unit tests / 474 files, production type-check/build and traceability PASS
  (39 requirements; committed index only, approved brief unavailable on Mac).
- 21 new browser scenarios plus 7 existing profile scenarios PASS. Matrix:
  320/390/1024/1440px, 100/200% root text, actual native browser zoom 200%
  independently measured at 640/780/2048/2880 window pixels; touch, reduced
  height, focus/close/return, long names, groups, pagination, empty/loading/
  denied/retry, own profile, DM, voice volume and MEMBER/ADMIN visibility.
- Complete registered shell/voice/screen Web gate: 18/18 stages PASS on the
  accepted clean source. This includes full unit/build, all 14 applicable browser
  configs and both complete actual-stack journeys. Raw REVIEW_REQUIRED with
  visual_review NOT_RUN is retained; selected manual review is separate.
- Real Go API/PostgreSQL/Tempo/LiveKit at desktop1440/DPR2 and touch393/DPR3:
  profile-to-DM opening, keyboard focus return, individual voice volume 100→101→
  100 on the same transport, contextual admin action visibility and actual MEMBER
  voice-kick API 403. Both complete media/fault/reset journeys, telemetry,
  persistence after API restart and owned-resource cleanup PASS.
- Six exact-master reconstructed Before and 13 selected After fixture frames
  reviewed at source resolution; all 13 final gate hashes match reviewed paint.
  Six selected actual profile frames reviewed separately. Compact card stays
  clear of protected controls. At 200%/short height, scrolling is intentional:
  focusing DM brings it fully inside the card; header/close may need scrolling
  back or keyboard navigation, while Escape remains available.

The private original tour 01/29/41 pixels are unavailable. Before uses the exact
master UI with controlled synthetic fixtures; one own-account fixture ID changes
its avatar color. These are selected review captures, not approved goldens.
Existing Vite ResizeObserver warnings also occur in prior accepted master
chat/mini-player fixture logs; they remain visible and are not suppressed.
No native, physical screen-reader, hardware capture or media QoE claim is made.

## Earlier failures retained

The clean first source `7ca5819d` completed 25/27 stages, raw FAIL: the legacy
error text assertion omitted Retry, and actual desktop voice backdrop click
failed. Touch393 actual passed. Backdrop coverage and avatar marker geometry
then failed focused tests before their fixes. Source review selected the compact
16px title token. Two subsequent clean local runs (`6272114a`, `1c442b5d`) were
interrupted before API/SFU setup for the 20px Retry target and lost retry-focus
findings; they remain explicitly superseded/partial, never PASS. Focused
regressions failed before each correction. The final clean source passed the
complete 18-stage applicable gate, including both actual runs, without skipping
assertions or treating an interrupted report as acceptance.

Full hashes, raw stage statuses, local paths and source-file bindings are in
[the machine record](dw11-member-panel-2026-10-17.json). Fresh final-head CI and
exact-tree publication remain mandatory before merge; the PR body records the
final CI runs, retained artifact digest and merge/issue closure receipts.
