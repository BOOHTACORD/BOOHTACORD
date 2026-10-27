# Open QA sweep — 2026-10-27, checkpoint 1

The goal covers all 37 QA issues open at intake. It remains **IN_PROGRESS**.
`matrix.json` preserves 480 extracted requirement/dependency rows, including
historical checkbox claims as input, never as new runtime PASS. PENDING rows
have not been executed. Nine macOS gates require a real Mac; three load gates
require an approved isolated target and calibrated host cohort.

`cases.json` is the explicit invariant → command/input → platform → mandatory
trigger → result mapping for the executed scopes. It does not promote a partial
witness to the full acceptance criterion. `manifest.json` binds retained files
and runner-source bytes. Exact installed candidates and verified hashes are in
[the physical candidate record](../../android/physical-share-2026-10-27/result.json).

Production Web source remained `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`.
API source is UNKNOWN. Android remains signed 1.0.45+2080; Windows 1.0.47+82.
Live release collection readback confirmed those are the latest public stable
Android and Windows releases in the current first page, not a new master build.

## Observed outcomes

- Actual headed Chrome DM journey PASS: both participants200, outsider MEMBER404,
  anonymous401; navigation draft retention, reload discard (required by #131),
  send/peer display, reply/cancel, edit/peer update, reaction toggle, cancel-delete,
  confirmed delete, real PNG upload/viewer/download, post-delete file denial.
- The third ADMIN privacy row is NOT_RUN: no controlled administrator browser
  session was supplied. This MEMBER witness does not close #53.
- Physical Android quick jump opened an owned peer DM. One new synthetic message
  from Chrome appeared on the actual phone within a 2450ms UI-polling upper bound;
  voice remained connected. This is neither p95 latency nor a transport diagnosis.
- A pre-existing reconnect banner disappeared after the visible Retry action.
  The first message attempt lost its target context during Retry and is excluded
  from delivery acceptance. After explicitly reopening the owned DM, delivery
  passed. No product bug is inferred from that invalid attempt.
- Muted Android background used screen-only FGS20; stop removed projection and
  all FGS while voice membership remained. Unmute restored mic80 + screen20;
  a later screen stop retained mic80 and released projection.
- Existing paired evidence confirms Chrome decoded Android frames and shipping
  Windows remained pending: defect #579. A later same-browser projection restart
  decoded10 frames after foreground source motion. Static/background source and
  first-frame timing remain unresolved; no FPS/capacity/automatic recovery PASS.
- Web Ctrl+K: 1440px PASS. At800/390px the focused launcher receives actual Ctrl+K,
  but its ancestor is role=dialog and search stays hidden; clicking the same
  launcher opens it. Filed as #580; independent of the accepted Messages mode.
- Native Windows setup opened and Escape eventually returned to workspace.
  Exact focus restoration, complete traversal and visual layout are NOT_PROVEN.
- Public health200; anonymous voice roster401. Windows and Android update
  selectors return503/no-store; existing deployment acceptance #249 remains open.
- Human audibility is NOT_RUN: the user cannot listen now. No PCM was captured.
- Samsung physical 2× system text review: the owned-DM composer and five voice
  actions remained visible above Gboard; three sampled controls measured48×48dp.
  Original1× font and voice connection were restored. Source-sized control crops
  exclude the synthetic peer header/message area; no approved golden is claimed.
  [Review and limits](android-text-scale-review.json) distinguish visual IME proof
  from the runner's incomplete active-app hierarchy heuristic.
- [Physical native message actions](native-chat/summary.json) now pass scoped
  Gboard Cyrillic input, Back/draft retention, send with browser rendering,
  edit revision2, reaction count1→0, cancel-delete preservation and confirmed
  deletion observed by the authorized peer. Only the owned fixture was changed;
  voice/microphone remained active and the message was cleaned up. Explicit
  message actions were used; body long-press acceptance is not claimed.
- [Actual OS microphone denial](voice-permission/summary.json) kept the phone
  connected as a listener without microphone FGS and without a repeated prompt
  in three follow-up samples. Original permission flags were restored exactly.
  The initial controller left listener mode active and its incomplete restoration
  is retained; explicit leave/HOME/resume/rejoin restored mic80 and the actual
  peer roster from3/muted2 to the original3/muted1. Audibility is still NOT_RUN.
- [Notification readiness/consent](notification-readiness/summary.json) verifies
  actual operator-off/Web-Push-unavailable state, honest disabled device UI,
  account consent keyboard toggling without permission/device registration,
  invalid-Origin403, anonymous401 and wrong-account409. Logical owned preferences
  were restored. Provider delivery/tap is BLOCKED by real deployed configuration;
  no operator setting or provider credential was changed.
- [Physical Android populated prejoin](native-prejoin/summary.json): quick-jump
  VOICE selection shows the two actual peers before joining, with RECORD_AUDIO
  denied, no permission prompt/microphone FGS, and both explicit join choices.
  Both peer names were matched privately; public image masks names/avatars.
  The first harness used wrong button labels; corrected shipping labels passed.
  Exact original permission and connected microphone/roster state were restored.
- [Actual browser logout/account switch and Swagger](web-session-contract/summary.json):
  old cookie401, settled Back and second-tab reload show guest, B→C→B clears drafts,
  C cannot read B's DM404; logout dialog passes Tab/ShiftTab/Escape/focus return.
  BFcache was not observed and is not accepted. The exact current public contract
  renders129 operations with118 security indicators and excludes3 private routes.
  Separate anonymous production session200/protected401/logout204 checks passed.
- Android opened the actual Google DocumentsUI file chooser from the owned DM;
  Back/cancel returned to the empty composer with voice and mic80 still active.
  No file was selected, and no personal file listings or picker images retained.
- [Physical Android PNG lifecycle](native-image/summary.json): actual DocumentsUI
  selection/send, native ICC-aware raster probe, browser decode/Escape/focus,
  participant200/outsider404/anonymous401, native delete and peer tombstone.
  Original access after deletion404; own phone fixture removed; voice/mic preserved.
  Initial numeric raster probes ignored the screenshot's Display P3 ICC profile;
  corrected conversion passes. No product defect or broad color-quality claim.
- [Windows native admin entry](windows-admin-entry-attempt.json) is NOT_RUN:
  supported CUA twice rejected the observed account-menu element as unavailable
  in its cache; reobserve/activate did not recover. Admin navigation was not
  performed, exact focus restoration is unproven, and no app defect was inferred.

## Reproduction and privacy

Commands in cases refer to ignored `.out/qa-goal/` runners on this Windows host.
Exact executed source is retained as non-executable `runner-source/*.txt` for
review/reproduction. Copy to the corresponding `.out/qa-goal/` filenames to rerun;
Playwright dependencies and the existing private controlled-account inputs are
required. No private input, browser cookie/storage state, password, account/DM ID,
message payload, attachment contents, SDP, raw app log or device serial is included.
Only owned synthetic conversations/messages/files were mutated. Messages were
deleted after checks; no shared guild configuration, deployment or server fault
was changed. Retained accounts/private sessions stay local for later packets.

Earlier harness failures are retained and distinguished from product defects:
VOICE SHARE_TEST was not a Web TEXT quick-jump result; browser reload intentionally
discards drafts; reaction actions require opening the current disclosure; an image
viewer attempt passed after bringing the actual page to foreground, without a
controlled attribution of that earlier failure. The final DM journey passed.

## Remaining work

Execute remaining Windows/Android/Web criteria, review the shortcut defect,
finish platform/criterion command mapping, then reconcile every QA issue with
evidence and exact blockers. No QA issue is closed by this checkpoint. Provider
E2E, Mac/iOS/Pixel, calibrated media/load, all screen readers and real-user UX
measurements remain separate gates. No test consolidation or deletion occurred.
