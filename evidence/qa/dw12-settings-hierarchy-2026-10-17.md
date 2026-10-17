# DW-012 / #351 — settings and administrator form hierarchy

Date: 2026-10-17, Europe/Istanbul. Parent #339. Web only.
Base master `25be6ecac1a404469833da284f6d1ce70a350a47`; accepted clean source `3b9da4eb056316b1c525eb1ed1f5b15dd5deb1a7`.
Dependencies: T-050, T-014, T-020, T-022, DW-003, DW-004.

The survey below covers the 13 named settings/admin surfaces corresponding to the
issue scope. The original private Tour 03–15 images are unavailable; this is not
an assertion about their exact frame numbering or pixel equality. Before images
use production components from the exact base master, with controlled synthetic
fixtures. No new golden baseline was approved.

## Survey and concrete changes

| Surface | Observed persistent copy / hierarchy | Decision |
|---|---|---|
| Guild | Name length rule; title explanation already in details; Save always active with no edit state | Keep validation/helper details; add dirty/pending/saved state, explicit Cancel, disable unchanged Save. Cancel after 409 uses freshly read baseline without automatically overwriting the draft. |
| Members | No competing helper paragraph; desktop Refresh clipped to one pixel | Keep existing table/cards/filter/mutation flows; expose existing Refresh action. |
| Roles | Scope applies to every member of role; destructive permission warning; dirty status hidden on mobile; defaults hidden until hover | Keep scope and deletion warning, all six ACL bindings and immutable admin policy. Expose dirty status and Defaults/Cancel/Save together. |
| Channels/category inspector | Parent/category/channel counts and ordering; contextual form results and danger confirmations | Already describes the selected resource rather than general advice. Preserve forms, ACL, confirmation and conflict review; no duplicate shell/mobile implementation. |
| Audit | Long loaded-page explanation repeats loaded count already in result status | Shorten to filter-on-loaded-records/next-page instruction; keep loaded count, privacy scope, errors and pagination visible. |
| Media | Last-60-seconds/privacy scope; freshness/error/empty instructions; technical interpretation already in details | Preserve: these distinguish missing reports from measured zero and stale results from current ones. No capability claim or cosmetic rewrite. |
| Readiness | API-vs-private-health paragraph; six capacity cards; local-journey tutorial dominates service result | Put explanation in “Что проверяется”, capacity and local-journey controls in labeled details. Keep headroom value in summary, dependency states, age, stale/pending/error/403 visible. |
| Profile | “Так вас видят…” and “Используется для входа” duplicate self-explanatory field labels | Remove redundant helpers. Keep read-only login, avatar/name actions, validation and explicit acknowledgement; add Cancel beside Save. Actions grow in normal form flow. |
| Security | Persistent paragraph explaining that the explicit Update password button requires clicking | Replace with unchanged/dirty/pending/result status plus Cancel/Update password. Keep logout consequences, session revocation warnings, validation and confirmation. No password mutation on Cancel. |
| Notifications | Browser background-delivery explanation; repeated mode/DM-preview paragraph | Put operational details behind named summaries; keep DM privacy and browser denial/error status visible. Existing immediate preference updates retain their semantics; no new Save/autosave claim. |
| About | Version value, check result/action already clear | Preserve update flow; remove inherited empty fixed card height only. |
| Basic audio | Devices and activation mixed with all processing/shortcut sections; refresh invisible until hover; device-check help visually clipped | Keep microphone/output/mode/sensitivity and their effective values/errors visible. Expose Refresh and actual keyboard-discoverable device help. |
| Advanced audio | Always-visible processing/shortcuts; technical paragraphs; “Reset audio settings” actually resets only participant/stream volume | Native mounted “Дополнительно” disclosure for AGC/NS/echo/gain/shortcuts and technical panels. Diagnostics become label/value list. Rename reset to actual scope. Lift clipping, processing failure/fallback and volume warnings outside disclosure; sensitivity/microphone persistence/permission errors remain in basic section. |

## Scope boundaries

The #295 admin tab shell, KeepAlive state, mobile navigation and existing
confirmation/conflict flows are reused. #297 profile tabs, logout/session guards
and personal-settings stores are reused. #342 themed controls remain in use;
this change concerns content/disclosure/action visibility and growing form rows,
not a second control skin. #343 contextual help conventions are retained.
No backend ACL, secure-cookie/Origin/CSRF contract, media transport, or native
client implementation changed. Existing immediate audio/notification setters
remain immediate; explicit profile/guild/password forms still require Save.

Native details keep audio components mounted. Clipping, settings persistence,
permission, processing-failure/fallback and volume warnings remain outside the
Advanced disclosure. RNNoise availability, AGC manual-gain locking/remembered
value and PTT/shortcut assignment behavior are preserved. The reset action now
names only the participant/stream volume scope it actually changes.

## Verification

- 1567 unit tests in 474 files; three new guild edit/conflict/cancel tests were
  written and failed before implementation. Focused initial browser checks also
  demonstrated missing Advanced/edit-state behavior before implementation.
- Production Vue/TypeScript/Vite build passed. Traceability passed for 39
  requirements using the committed index; the approved Windows brief is absent.
- 19 focused browser cases: all 13 surfaces at 390/1024/1440, axe/keyboard,
  text scale 200%, real browser page zoom 200% at windows 780/1440, retained
  AGC/NS/echo/gain/shortcut values, PTT, visible failures, dirty/pending/Cancel,
  403 and 409 draft preservation, readiness stale/error/disclosure controls.
- Full applicable local gate `.out/local-features/20261017-131717`: **17/17 PASS**, clean source
  above. The raw report remains `REVIEW_REQUIRED` / visual review `NOT_RUN`;
  separately recorded source-resolution review covers 13 selected Before and
  37 selected After component frames, plus separate actual-client frames/crops.
  It does not silently approve every generated frame or a replacement baseline.
- Actual owned Go API/PostgreSQL/LiveKit at desktop1440/DPR2 and touch393/DPR3:
  explicit profile save/read-back/restore and cancel; password cancel without
  mutation; notification privacy; Advanced values retained; same live peer
  connections across audio settings; full lifecycle persistence/restart and
  owned-resource cleanup. All eight settings acceptance flags passed at both
  widths. Synthetic media does not establish hardware capture/audio quality.

## Visual observations

The primary audio page has devices/mode/sensitivity followed by a labeled
Advanced disclosure rather than permanent processing/shortcut cards. Refresh
and device-help summaries are discoverable. Expanded controls preserve values
and their safety/scope text; technical diagnostics use label/value rows.
Profile helpers no longer repeat labels; Save/Cancel/status grow within the form
instead of occupying an absolute lower edge. Mobile roles retain the warning,
dirty status and all three actions. Readiness prioritizes effective dependency
state/age, while preserving the real headroom number in its technical summary.
Labels/actions wrap without horizontal document overflow at the checked sizes.
Intentional vertical scrolling, horizontal tab navigation and native-select
value truncation are not reported as missing content; full hardware labels
remain available. Exact frame paths/hashes and source-pixel crop references are
in the JSON record. Actual screenshots show selected live scroll positions,
while complete forms are covered by component captures and interaction checks.

## Earlier attempts

The first gate was stopped before integration after an old readiness geometry
test tried to measure a closed capacity disclosure. It now opens the disclosure
and retains all geometry/value assertions. The next complete run had 16 passing
stages (including both actual clients), but microcopy could not bind a port held
by an owned orphan from that interruption. After verifying its command/cwd and
terminating exactly that process, the retry found an old password-helper text
assertion. It now verifies unchanged/dirty state, explicit Update availability
and cancellation, while retaining security consequences. The final complete
17-stage run is acceptance; all prior FAIL/partial records remain unchanged.

Fresh final-head CI and exact-tree merge/closure are required before completing
the issue; their run/artifact digests and final receipt are published in the PR.
