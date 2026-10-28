# Open QA sweep — 2026-10-27, checkpoint 1

The goal covers all 37 QA issues open at intake. It remains **IN_PROGRESS**.
`matrix.json` preserves 480 extracted requirement/dependency rows, including
historical checkbox claims as input, never as new runtime PASS. NOT_RUN rows
have no fresh complete-row execution; existing partial witnesses retain their limits. Nine macOS gates require a real Mac; three load gates
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
- [Actual Web JPEG/GIF lifecycle/downloads](web-image-formats/summary.json):
  preview decode, no auto-send, original card download, Escape/focus and both
  protected file variants pass for two members/outsider/anonymous and deletion.
  Viewer Download FAIL: PNG bytes receive original jpg/gif extension. Actual
  download events prove the mismatch; all owned messages/temp downloads cleaned.

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

## Isolated tracing checkpoint

[Actual tracing results](trace-runtime/summary.json):8 Go invocations,42 top-level
test executions (including the required recovery rerun),4 subtests and no skips;
9 dashboard semantic tests and78 TraceQL executions passed. Browser/native SDK
fixtures retain their synthetic limits. The dashboard controller failed on CRLF;
its original9/9 OK log and same-log receipt recovery are retained. Actual Collector
and Tempo outages were confined to the owned loopback namespace; all its containers,
network and attached volumes were removed, unrelated container states unchanged.
No production Grafana, packaged-client trace, audibility, capacity or hosted CI
acceptance is implied. Parent QA issues remain open.

## Physical Android PTT checkpoint

[Actual signed-device PTT](native-ptt/summary.json): native touch UP, outside-UP,
CANCEL and HOME all returned the exact phone account to server-reported mute.
Resume did not unmute. Three room participants stayed present. VAD mode, original
unmuted microphone/permission and owned empty DM were restored. Source-sized
control crops were inspected. No audibility or receiving SDK/PCM claim is made;
immediate FGS snapshots have asynchronous lag. The original UIAutomator/encoding
controller limits remain explicit. No full QA gate is closed.

## Physical Android orientation checkpoint

[Two actual rotation runs](android-orientation/summary.json) preserved the owned
draft and voice membership, but landscape with Gboard failed visual acceptance:
the voice Leave control covers Send, with123×81px overlap; filed as[#582](https://github.com/Egkurilov/BOOHTACORD/issues/582). Android Back exposes
Send again. Original rotation settings, empty draft, permission and voice were
restored after each run. Published source-sized control crops mask the draft.
No tap in the overlapping region or accidental-disconnect claim is made.

## Physical Android connectivity checkpoint

[Actual Wi-Fi→cellular delivery](android-connectivity/summary.json): own native
DM reached and rendered on the PC while Wi-Fi was off and CELLULAR was the actual
default before/after delivery. The final corrected repeat passed end-to-end
server/PC/native fixture cleanup and restored Wi-Fi, permission, mic FGS and
roster3/unmuted. It captured Android9c221897, Chrome155 and Web072426d6 identities.
Earlier partial/controller-cleanup failures remain separate retained receipts.
No acoustic, packet continuity or explicit SDK reconnect event claim is made.

## Execution map

`acceptance-methods.json` maps24 native/manual methods to the protected invariant,
command, platform, mandatory trigger and result location. Every preserved source
row now references applicable methods. These are execution plans, not runtime PASS.
The480 rows include391 acceptance requirements,21 evidence requirements,7 historical
claims,29 context rows and32 dependencies; they are not480 independently run tests.
Measured prerequisites and exact constraints are retained under `prerequisites/`.
Local Docker29.6.2, Go1.26.4 and Flutter3.47.7 are available for isolated subsets.

Viewer download mismatch is filed as[#581](https://github.com/Egkurilov/BOOHTACORD/issues/581);
the separate original-file card download passed. No parent QA issue is closed.

## Remaining work

Execute remaining Windows/Android/Web criteria, review the shortcut defect,
execute the mapped source/platform variants, then reconcile every QA issue with
evidence and exact blockers. No QA issue is closed by this checkpoint. Provider
E2E, Mac/iOS/Pixel, calibrated media/load, all screen readers and real-user UX
measurements remain separate gates. No test consolidation or deletion occurred.

## Production native resume — 2026-10-28 Moscow

[Three scoped DM facets](production-native-resume/summary.json) pass on the physical Android2082 and actual Windows Chrome. Outbound Web072426d6 and final inbound Web8a2cda38 are recorded separately. Recovery/controller/clipped-viewport attempts remain retained; they do not establish a new product regression. The final two fresh UI messages arrive without native refresh and reveal full body bounds after explicit scrolling. Owned fixtures are removed; session/trust/router and active media preserved. No fault/load injection, automatic-scroll, latency, acoustic, whole-platform or broad QA PASS is claimed. Isolated native HTTPS/fault acceptance remains BLOCKED on a trusted QA origin.

## Physical Android sender / two Web receivers — 2026-10-28 Moscow

[Source-bound numeric results and limitations](native-sender-two-receivers/summary.json): signed2082/source072426d6 published public Settings app-only to two actual Chrome155/Web8a2cda38 listeners. Native counters and HTTP success milestones grew; receivers decoded12→54 and12→56, with presentation callbacks. Initial30s first-frame wait failed before later source scrolling; root cause unknown. Parent bottom dock Stop cleared projection/screen FGS while retaining voice/mic;68s of sender-event quiet and two cleared receiver snapshots followed. Toolbar/guard failures and the missed240s bound are retained. No calibrated QoE/RTT/source-FPS/acoustic/whole-platform acceptance; all parent gates remain open.

Initial-frame finding after approximately150s in the system picker is tracked as [#584](https://github.com/Egkurilov/BOOHTACORD/issues/584). Exact issue/QA body readbacks are retained in native-sender-two-receivers/github-updates.json (packet-local github-updates.json).

## Physical Android admin shell — 2026-10-28 Moscow

[Scoped admin results and limits](native-admin/summary.json): all seven native
section selectors were reached at real system font1.0/1.3/2.0 (21 transitions).
Sampled tab/Close targets retain nominal44dp with1px integer rounding allowance;
all25 static chrome crops reviewed at original resolution. Actual IME/Back at1.0,
role-popup cancellation and root Back into the original DM passed.2.0 input
remains unaccepted after retained controller failures; no product defect inferred.
Font, empty local filters/composer, session and original voice/mic restored.
I287.C14 is PARTIAL; existing FAILs in I303.C2/C3 remain. Full admin/platform/AT
gates are open. No product/tests or43 consolidation decisions changed.

Web-to-Android receiver preparation remains NOT_RUN: supported Windows Computer
Use stopped on insufficient browser-URL confidence. No alternate UI bypass or
receiver runtime occurred; see [exact prerequisite receipt](prerequisites/web-to-android-cua-stop.json).

## Physical Android Gboard counterexample — 2026-10-28 Moscow

[Actual Gboard input](native-admin-gboard/summary.json) resolves the previous
2.0 uncertainty with a confirmed physical failure: two separate2x runs retain
the exact first character, then lose field focus and hide IME before any Back.
The1x control retains four exact Cyrillic prefixes, focus and IME; explicit Back
keeps admin/query. Observation assertion exits are1/1/0. All8 keyboard/own-field
crops reviewed at original resolution; source/installed APK fingerprints retained.
Original DM/font/empty filters/voice restored. I287.C14/I301.C4 now FAIL; all
480 source requirements and earlier failures preserved. Full gates remain open.

Подтверждённый large-text input defect: [#585](https://github.com/Egkurilov/BOOHTACORD/issues/585). Exact bug/QA body readbacks: `native-admin-gboard/github-updates.json`.

## Physical native ADMIN search privacy — 2026-10-28 Moscow

[Two scoped native privacy witnesses](native-admin-search-privacy/summary.json):
server-attested current ADMIN searches All and renders only an allowed fixture,
while both allowed/foreign fixtures remain searchable to their participants.
After both owned messages are deleted, actual same-query native resubmit shows
No matches. Static/empty crops reviewed at original resolution; initial AX-count
controller failure and clipped empty crop remain retained. Original query/scope,
own DM/font/empty composer/permission and unmuted voice/mic restored. Windows uses
only APIRequestContext fixture controls; no browser/UI or native auth extraction.
I287.C3 is now PARTIAL. Full browser/hints/unread/notification/file/revoke/search-filter
acceptance remains open; all480 original requirements and known failures preserved.

## Physical Android search target — 2026-10-28 Moscow

[Actual scope-dropdown geometry and hit probes](native-search-touch-targets/summary.json)
fail the Android48dp gate: observed scope frame32dp, center/inside edge points
activate, but points2px/9px above and below do not. All8 probes preserve query and
scope; observed popup Back and final native DM/font/voice cleanup pass. Redacted
source-sized control strip reviewed. I301.C6 now FAIL; historical44dp witnesses and
other existing failures stay intact. Whole target inventory/other platforms/AT
remain unaccepted. All480 original requirements retained; no product/test edits.

Physical Android search target defect: [#586](https://github.com/Egkurilov/BOOHTACORD/issues/586). Exact bug/QA readbacks: `native-search-touch-targets/github-updates.json`.

## Isolated actual API login denials — 2026-10-28 Moscow

[Source-bound I240.C4 results](isolated-auth-denial/README.md): actual Go API and
PostgreSQL17.6 produce90/90 equal401/UNAUTHENTICATED responses without cookies or
new sessions across unknown/active-wrong/blocked-wrong groups. Correct active
and blocked controls, finite30/group timing distributions, bounded owned log
marker scan and6 focused native Go tests with zero skips pass. Owned fixtures
are unblocked and sessions revoked; all9 local services remain running/private.
I240.C4 is PASS for its exact backend requirement. QA240 stays FAIL/open with
defect134 and unfinished rows. No Nginx/TLS/native-login, other platform/media,
production-capacity or statistical timing-channel-absence claim. All480 original
requirements, previous failures and43 consolidation decisions are preserved.

## Actual isolated WebSocket quotas — 2026-10-28 Moscow

[I240.C3 source-bound results and retained controller failures](isolated-websocket-quotas/README.md):
real API/PostgreSQL17.6 enforces unchanged deployment500/account5/session2 quotas
under concurrent attempts. Strict429 contract,30 failed upgrades, graceful/TCP
close, reconnect,1/10/100/500 stages and two100-client reconnect cycles pass.
500 sockets held20s yield500 actual revalidation calls without failures; all
owned sockets return to0. Safe API/DB resource samples and6 native Go passes with
zero skips retained.104 own test accounts reused; all936 historical own session
rows revoked; original9 services healthy/private. I240.C3 is PASS for its exact
backend scope; QA240 remains FAIL/open. No full implementation135, WSS/browser/native
retry, prompt-revocation SLO, platform/media or capacity gate claim. All480 source
requirements and43 consolidation decisions preserved.

## Actual login budgets / NAT20 counterexample — 2026-10-28 Moscow

[I240.C5 runtime failure, passing controls and source-bound commands](isolated-login-budgets/README.md):
two20-account same-source cohorts each produce10 successful valid logins and10×429;
reversed order/fresh-source controls isolate the unchanged10/5min network budget.
Referenced137 NAT20 acceptance remains unmet. Exact counterexample exits1;
account8/30s before KDF, real32s/302s window recovery,64-account KDF burst/manual
retry and finite-label audit pass in their stated scopes.11 native units PASS,
zero skips; the intentional11th-IP rejection regression is preserved.64 new
sessions revoked, all1000 historical own sessions inactive,104 own members reused,
9 services healthy/private. I240.C5 now FAIL; canonical fix137 is reused. Other
upload/platform/media facets remain queued;480 source texts and43 decisions intact.

## Actual upload rate windows, 2026-10-28

[Scoped upload evidence](isolated-upload-budgets/README.md) passes actual unchanged account10/source200/deployment5000 windows,16-way global boundary and real302s recovery. Seven focused native checks pass with zero skips. I240.C5 and QA240 remain FAIL/open because the earlier NAT20/#137 counterexample remains. Six own32B files are intentionally retained; all2011 historical owned sessions are inactive. No original consolidation decision is applied.

The requested [production URL readiness](production-origin-readiness/result.json) separately observed trusted HTTPS and root HTTP200 from this PC without credentials. `/healthz` returned the same HTML SPA fallback; it is not an API health result or access to the isolated local stand.

## Actual limiter-store saturation and matched measurements, 2026-10-28

[I240.C7 evidence](isolated-rate-capacity/README.md) now passes the exact source-store/race/benchmark criterion: real10000-key boundary, preserved active budget, failclosed unknown keys, real304s recovery and bounded64 expiry batches.12 native race tests repeat3 times with zero skips. Historical/current matched timings retain both improvements and regressions, and distinguish instrumented-copy hold diagnostics. Database counts and nine private services remain unchanged. QA240 remains FAIL on134/137; no43 consolidation decision is applied.

## Trusted-source header differential, 2026-10-28

[I240.C6 evidence](isolated-proxy-source/README.md) records a conditional repeated-XFF defect for canonical138:5/100 primary case failures and3/18 literal-wire failures, while default Caddy/untrusted-peer controls pass30/30. Equivalent combined field chains retain429; separate fields reach malformed-parser400. Three focused native regressions fail3 repeats each;19 original/config controls pass with zero skips. All DB/config/source and nine services remain unchanged; two own peers were removed. QA240 stays FAIL with134/137/138. Actual runtime bridge permits outbound access; API/admin remain unpublished and host ports loopback. No consolidation decision is applied.

## Production screen binding / actual SDK-SFU lifecycle, 2026-10-28

[I240.C8 evidence](isolated-screen-preview/README.md) passes27 real production-factory/SDK/SFU stages: unselected0/selected1 subscription and renderer, selected/unselected unpublish, signal reconnect, new factory and delayed actual old callbacks.36 nearest native tests pass with zero skips. A served registry mutation produces2 unselected SFU subscriptions and is killed; original source stays unchanged. Own rooms/bridge are removed, original9 services remain healthy/private. This source-module headless integration does not close physical/native/production UI or Go lease/auth gates. QA240 remains FAIL on134/137/138;43 consolidation decisions stay untouched.


## Isolated TEXT edit eviction — 2026-10-28

[Source-bound counterexample and exact commands](isolated-history-edit-eviction/README.md): I240.C9/I241.C37 FAIL. Actual source components plus own Go API/PostgreSQL17.6 lose the uncommitted edit in3/3 primary repetitions;2 controls pass.13 closest tests PASS/0 skips. Canonical141 is reused; its fresh state/readback is recorded after publication. Full profile/physical/platform/hosted gates remain separate,43 consolidation decisions untouched.

75 scoped cases;480 original criterion texts preserved. Status counts: BLOCKED160, PARTIAL52, NOT_RUN244, FAIL19, PASS5. QA240/241 remain open/FAIL.


## History source performance matrix — 2026-10-28

[Measured20-dataset before/current comparison](isolated-history-profile-matrix/README.md):120 calibrated browser profiles,3 repetitions/source,60 focus and30 same-row anchor checks; current settled cache<=500, historical DOM guard rejects45 actual old-source counterexamples. Exact I241.C36/C38/C39 PASS in the declared source/owned-API scope. I240.C9/I241.C37 and canonical141 remain FAIL on lost uncommitted edits. No physical/native/hosted/media gate or43 consolidation decision is closed.

76 scoped cases;480 original criterion texts preserved. Counts: BLOCKED160, PARTIAL52, NOT_RUN241, FAIL19, PASS8. QA240/241 remain open/FAIL.


## Built Web history context navigation — 2026-10-28

[Five-scenario real-stack evidence](isolated-history-context-navigation/README.md) passes reply/search/unread outside the loaded window, same-row/focus return, bidirectional context, channel restore and actual UI logout/account reset.6 units/0 skips;2 reply/search repeats. All1320 fixture rows/3channels removed,10 own sessions revoked,9 original services unchanged. I240.C9/I241.C37/141 retain FAIL for known edit-draft loss.77 scoped cases;480 original texts and43 consolidation decisions preserved. No native/physical/production/media/hosted gate is promoted.

The additional same-document account journey passes8 lifecycle assertions without acceptance reload/goto, strengthening the primary wrapper. Across both phases:1321 own rows/4channels/2categories removed,14 own sessions revoked and final nine-service/source/privacy checks PASS. See the linked history context evidence; no full QA/physical/hosted gate is promoted.


## Already-open context realtime freshness — 2026-10-28

[Distinct source-bound failure](isolated-context-realtime/README.md):3 edit +3 delete targets remain stale after real matching hints/correct protected API state.5 controls and6 fresh-after-explicit-reload controls PASS;12 closest checks/0 skips do not cover the live path.201 own rows/2channels/category removed,5 own sessions revoked;9 original services/source unchanged. I240.C9/I241.C37 remain FAIL; distinct fix [#587](https://github.com/Egkurilov/BOOHTACORD/issues/587) is filed/open after duplicate review, linked to immutable evidence with exact readback.78 scoped cases/480 original texts and43 decisions preserved.

## Critical DM/image deletion checkpoint — 2026-10-28

[Protocol privacy and physical viewer evidence](production-dm-image-revocation/README.md):25 reviewed API boundaries PASS_SCOPED, plus separate opaque409/denied-body controls; already-open Android viewer FAIL in a24,766ms post-control observation window despite fresh underlying history and server404; exact pixel probe is inside that window, not continuous sampling.15 widget tests pass/0skip. Both own messages/all3 owned API sessions cleaned; source/candidate and visual hashes retained.80 scoped cases; all480 source texts and existing row statuses preserved. ADMIN/other formats/platform/media/hosted gates and43 consolidation decisions remain unaccepted.

Tracked Android defect: [#589](https://github.com/Egkurilov/BOOHTACORD/issues/589), exact readback/open. QA53/62/131 updated with prior-body prefix preserved and stay open. Immutable first evidence: 36b360bb8aa7663dceeb6e272c085826020b4c69. Hosted wrapper observation is NO_HOSTED_PASS_OBSERVED, not full check enumeration or gate acceptance.
