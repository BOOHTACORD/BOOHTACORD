# Current shared-client parity contract (#518)

The machine-readable scenario matrix lives in the existing
[`tools/qa/local_features/features.json`](../tools/qa/local_features/features.json),
under each feature's `parity` records. Stable IDs cover auth/session/security,
TEXT/DM/social/files, search/navigation, notifications, topology/admin,
voice/reconnect/PTT/devices, publish/view/mini/fullscreen/audience,
update awareness, telemetry and support (#516). This is the current source
comparison; historical reports below keep their original build/date scope.

`PARITY` means the sources implement the same expected user result. It does
**not** assert physical runtime acceptance. `GAP` requires a tracking issue;
`PLATFORM_EXCEPTION` needs a reason and an available alternative; `PLANNED`
is shared future scope; `NOT_VERIFIED` does not become a pass because Dart is
shared. Each client has its own runtime state, permissions/conditions and tests.
The final [#518 report](../evidence/qa/issue518-client-parity.md) binds actual
runs/builds to source and records outstanding physical gates.

Every PR changing a common scenario updates `parity_review` for affected
features: implementation and regression on Web/iOS/Android, an agreed platform
exception, or a linked gap. CI rejects duplicate IDs, missing client paths/tests,
missing platform decisions and unsupported runtime PASS claims. It also runs
the existing Web/Flutter suites; metadata validation alone is not a behavior test.
A shared Dart implementation is one code path with **two distinct native runs**.
Never delay an urgent security fix for simultaneous releases: track the second
client as an explicit priority gap. Coordinated noncritical features can use an
agreed feature flag until applicable clients are ready.

PAR-01/02: durable cursor advances only after awaited effects; bounded queue
and dedup, overflow/handler error/expired cursor reset to server snapshots.
Cursor is memory-only and bound to server/auth scope/capabilities. Socket-open
is not protocol-ready: only `connection.ready` resets jittered retry; generation
changes cancel old callbacks/timers. The UI exposes recovery and manual retry.
PAR-03 preserves lease heartbeat and polling fallback while coalescing scoped
empty viewer hints. PAR-04 is the existing Guild settings telemetry panel:
admin-only API, explicit consent/HTTPS and honest delivery/error states.
PAR-05 keeps fullscreen exit separate from stop viewing; stop changes only
remote subscriptions and preserves voice/publisher state and renderer handoff.
PAR-06 updates the actual iOS app-only/broadcast paths in its README.

# Flutter ↔ web parity plan

## Flutter admin parity epic #188

The Flutter administrator workspace now has the same functional seams as the
web Design V2 admin surface. A shared width-class foundation uses the approved
breakpoints (compact `<600`, medium `600–839`, expanded `840–1199`, large
`1200–1599`, extra-large `≥1600`) while keeping the existing 880 px desktop
content bound. The implementation is intentionally additive: existing ACL,
mutation, cursor and revision contracts stay in their feature facades.

Implemented slices:

- Readiness uses the authenticated `/admin/readiness` contract, accepts a
  valid degraded `503`, marks results stale after 15 seconds, and shows
  database/SFU/storage probe cards with storage headroom and pending-revocation
  metrics.
- Members retain drafts through an `updated_at` optimistic-concurrency save;
  a `409` refreshes server state while preserving the local draft and exposing
  a before/current/proposed review. Expanded constraints use compact table-like
  rows with deterministic avatars, access badges and contextual actions; long
  names are ellipsized, while compact constraints retain expandable cards.
- Roles expose the web permission matrix, delete-grant confirmation, dirty
  role-switch protection and a before/current/proposed conflict review with
  explicit server/draft resolution actions.
- Channels add a selectable topology tree and keep the existing revision-bound
  create/rename/reorder/description mutations behind the inspector.
- Audit adds scope, actor, event-type and date filters, day grouping and
  expandable event details without exposing message contents.
- Media adds freshness state and explicit send/receive/decode/present stages;
  anonymous legacy measurements remain visible and advanced metrics are
  available on demand.
- Guild settings use a 600 px desktop form bound and full-width compact form,
  with helper copy and existing loading/error/saved states.

Focused widget/model/API tests cover the new slices. Android/macOS runtime
checks are recorded separately; Windows and iOS acceptance remain `NOT_RUN`
until those runtimes are available. This implementation record therefore does
not claim the parent platform gate is closed.

The follow-up accessibility pass adds regression coverage for the full admin
viewport matrix, including phone landscape and tablet landscape, plus a
text-scale 2.0 traversal through every section. That run exposed and fixed
large-text clipping in Channels dropdowns and the Audit, Media and Readiness
panels. The full Flutter suite passed 795 tests with one expected skip and a
release APK split build completed; native IME, TalkBack, focus-loop and
cross-platform runtime acceptance remain open —
[QA-ADMIN-ACCESSIBILITY-HARDENING-2026-10-07-001](../evidence/flutter/qa-admin-accessibility-hardening-2026-10-07-001.json).

The current branch was installed on the Android 15/API 35 emulator after that
hardening commit. The administrator surface passed a short portrait + landscape
smoke with all seven tabs visible and no app fatal exception; this does not
replace the remaining IME/TalkBack/iOS/Windows gate —
[QA-ADMIN-ANDROID-RUNTIME-2026-10-07-002](../evidence/flutter/qa-admin-android-runtime-2026-10-07-002.json).

The later compact identity follow-up added an expanded role selector for narrow
member cards and a long display-name/login regression at text scale 2.0. The
full suite now passes 796 tests with one expected skip; the current release APK
also launches on Android API 35 without an app fatal exception —
[QA-ADMIN-ACCESSIBILITY-HARDENING-2026-10-07-002](../evidence/flutter/qa-admin-accessibility-hardening-2026-10-07-002.json).

## Компактный composer — проверка 2026-10-05

В Flutter шириной до 720 px действия attach, paste, mention и emoji собраны под одним `+` menu для TEXT и DM; в wide composer emoji picker остаётся отдельным действием. Picker содержит шесть быстрых emoji, searchable полный каталог с русскими/английскими подписями, recents и вставку/замену текущего выделения в draft. Service/widget suite — 72/72, полный suite — 592/592, changed-file analyzer чистый; подписанный Android r47 и Mac Debug визуально проверены после DevTools hot restart. На Android API 35 системная floating IME-панель перекрывает часть левого края каталога, а часть новых Unicode glyphs отсутствует в системном шрифте. Web не изменялся; update catalog не менялся — [QA-279](../evidence/flutter/qa279-flutter-compact-composer-actions-2026-10-05-001.json), [QA-280](../evidence/flutter/qa280-flutter-emoji-picker-design-v2-2026-10-05-001.json).

## Design V2 Inter font (FV2-001 follow-up)

Flutter now bundles the same Inter Variable 4.001 source as Web, converted from
the project's WOFF2 to a Flutter TTF asset with the SIL OFL license. The family
used by `guildTheme()` resolves to a packaged font instead of an OS fallback.
The asset-loading test, Linux/Windows Flutter suites and analyzer, Android debug
APK, and Windows distribution passed in CI. [QA-250](../evidence/flutter/qa250-flutter-inter-font-2026-10-04-001.json)
records hashes and the open native visual acceptance.

## Design V2 guild navigation (FV2-017)

The Flutter workspace sidebar now uses a 64 px guild header with loaded member
count, a separate 36 px search row, 40 px segmented tabs, and a 64 px account
footer. At a 390×844 viewport, the 320 px drawer places search at
`(12,76,296,36)` and tabs at `(12,124,296,40)`, matching the R14 HTML
geometry. Search, tab selection, close, and focus restoration still invoke the
existing workspace state. The guild mark uses a native icon and V2 colors
without adding an image asset. The focused widget test also checks desktop
search spacing at 1440×900. [QA-248](../evidence/flutter/qa248-flutter-design-v2-guild-navigation-2026-10-04-001.json)
tracks CI and the still-open platform visual acceptance; no local Flutter SDK
or Android device is available on the Windows host.

## Search presentation follow-up (FV2-019)

Web commits `f593ec40` and `83f51439` refreshed the R13 search presentation after the original
Flutter search behavior was implemented. The current web target is a 380 px
desktop rail at widths ≥1280, a full-viewport compact overlay with a 44 px close
target, a compact scope selector and Enter hint, a visually hidden submit,
visible initial/loading/empty status and error feedback, result count,
conversation/date before author/avatar, and inline query highlighting. FV2-019
implements these presentation changes while preserving server search scope,
cursor pagination, context navigation, focus behavior, and authorization. The
Flutter-only follow-up fixes the clipped scope selector and blank initial state
reported by the user. Widget regressions, 63 workspace tests, and changed-file
Dart analysis pass. Runtime visual review on Android 1.0.28+2052 confirms the
compact overlay; the already-running Mac Debug window confirms the 380 px
desktop rail. The Mac window was not relaunched and no Keychain prompt appeared.
The local Android downgrade side effect reset the prior app session; the user
signed back in before visual acceptance. See
[QA-260](../evidence/flutter/qa260-flutter-search-panel-empty-state-2026-10-04-001.json).

## Connected voice dock presentation (FV2-020)

The current web follow-up gives a connected dock a headset marker, the status
“Голос подключён”, and a channel subtitle with the participant count. Flutter now
matches that copy and context, uses the headset in place of the status dot, and
reduces the connected label weight. Until the first quality sample arrives, the
unknown-quality visual placeholder is omitted on desktop while its accessible
description remains available; compact layouts retain the placeholder. Voice,
LiveKit and control behavior are unchanged. [QA-259](../evidence/flutter/qa259-flutter-design-v2-voice-dock-2026-10-04-001.json)
records Android emulator visual acceptance; [QA-261](../evidence/flutter/qa261-flutter-design-v2-voice-dock-macos-2026-10-04-001.json)
records the Mac connected-dock screenshot check and full-suite regression result.
Both runtime checks used a muted/listener-only session and confirmed the session
was left afterwards.

## Message attachment cards (FV2-021)

Flutter published-image cards now follow the current web layout: up to 440 px
wide, with a 200 px desktop or 144 px compact preview and a dedicated metadata /
download footer. Non-image files use the separate 340 px file card with a 44 px
file icon. Attachments form a vertical list and use Flutter Design V2 semantic
colors. Geometry, full-suite, analyzer, Android release and macOS Debug builds
pass. Android API 35 and the restarted Mac client both displayed the loaded
protected image preview; no message or upload behavior changed —
[QA-262](../evidence/flutter/qa262-flutter-design-v2-attachment-cards-2026-10-04-001.json).

FV2-030 closes the preview-failure presentation gap: when the protected
thumbnail request fails or its bytes cannot be decoded, Flutter now follows the
web fallback to the 340×62 file card with a 44×44 icon, while preserving the
click-through to the protected viewer and the separate download action. A
test-first regression reproduced the old 440×238 card before the fix. The
focused attachment suite passes 15/15, changed-file analysis is clean, the full
Flutter suite passes 595/595, and Android/macOS Debug builds pass. The already
running Mac stayed on its signed-in TEXT view; no live attachment was altered
to force a failure state, and no Android app was installed —
[QA-283](../evidence/flutter/qa283-flutter-attachment-preview-fallback-2026-10-05-001.json).

## Protected image viewer overlay (FV2-022)

Flutter now matches the web protected image viewer with a viewport-filling dark
overlay, filename header, separate authenticated download action, fit-to-window
image, compact/desktop controls, and loading/unavailable/retry/decode-error
states. Android runtime acceptance exposed a system-inset overlap that widget
tests had missed; the viewer now preserves `MediaQuery.viewPadding`, keeping its
header and footer clear of status and gesture bars without shrinking the
full-screen background. The 13 focused tests and full 526-test suite pass.
Runtime visual acceptance passed on Android 15/API 35 (signed local build
1.0.29/versionCode 2055) and the already-running macOS Debug app via hot reload;
Escape/Android Back both return to Text. Windows runtime visual acceptance is
still open — [QA-266](../evidence/flutter/qa266-flutter-protected-image-viewer-safe-area-2026-10-05-001.json).

## Admin role-permission list surface (FV2-023)

Flutter's role-permission `CheckboxListTile` is now under a `Material` surface
rather than a `ColoredBox`, preserving the existing content color while
providing the Material ancestor required for visible tile ink/background.
The test-first regression reproduced six framework warnings before the fix and
then verified all six permission controls plus a toggle without framework
errors. The focused admin tests passed 11/11; the full Flutter suite passed
551/551 and changed-file analysis was clean. The existing macOS Debug session
was hot-reloaded and visually checked on Administration → Roles. Android API
35 was checked on signed local build `1.0.29+2057` installed in place, with the
existing session/data preserved; no permission was changed or saved. The
change is client presentation/test-only — [QA-270](../evidence/flutter/qa270-flutter-admin-list-tile-warning-2026-10-05-001.json).

## Admin section tabs (FV2-024)

Flutter administration now follows the web tab-strip interaction: one
horizontal row, horizontally scrollable on compact widths, a 44 px minimum
target, 12 px horizontal button padding, 8 px desktop spacing/zero compact
spacing, and a 2 px accent underline for the selected tab. Tab and tab-bar
semantics are retained. The previous `Wrap` of `ChoiceChip`s was test-first
reproduced as three rows on compact screens; a separate desktop regression
caught the divider shrinking to the tabs' intrinsic width. Focused admin and
workspace tests pass 74/74 and changed-file analysis is clean. The existing
macOS Debug session was hot-reloaded and visually checked without restarting
or disturbing its authenticated session. Android API 35 was checked on signed
local build `1.0.29+2060` installed in place, preserving the existing session;
all five tabs fit at the emulator's compact width, and a horizontal swipe
confirmed that Media remains reachable. No role setting was changed or saved —
[QA-272](../evidence/flutter/qa272-flutter-admin-section-tabs-design-v2-2026-10-05-001.json).

FV2-025 closes the admin panel geometry gap: Flutter now constrains and centers
the content at 880 px, uses the web-aligned compact/desktop insets, and removes
the duplicate body heading while keeping one visible, focusable semantic
workspace header. Geometry tests cover 390/900/1440 px; focused admin tests
pass 13/13 and the full Flutter suite passes 567/567. macOS hot-reload visual
and accessibility-tree checks and Android API 35 visual acceptance pass —
[QA-274](../evidence/flutter/qa274-flutter-design-v2-admin-panel-width-heading-2026-10-05-001.json).
Windows-native visual acceptance remains open in FV2-006.

## Frameless desktop window chrome (FV2-018)

macOS and Windows now use a compact 32 px draggable title bar instead of the
system title bar. It shows a text-only Inter BOOHTACORD wordmark; macOS keeps its
native traffic lights and Windows has minimize/maximize/close controls. Mobile
is unchanged. Widget tests, the 482-test Flutter suite, changed-file analysis,
macOS Debug build and an inspected component capture pass —
[QA-252](../evidence/flutter/qa252-flutter-desktop-window-chrome-2026-10-04-001.json).
Live visual review of the already-running macOS Debug app confirms the text-only
brand and native traffic lights. Double-clicking the custom header maximizes
the window; a second double-click restores its original size. A running Android emulator confirms the
mobile header has no desktop chrome, and the current-source platform widget
regression passes. The emulator still has app version 1.0.28 from before this
desktop-only change, so its screenshot is a visual regression check rather than
a build-identity check. macOS native zoom/restore is verified. In the current
live session, DevTools confirmed pointer-down reaches the title-bar drag region,
but the desktop UI driver did not emit a pan-update; a read-only position check
stayed at `Offset(1000,238)`, so runtime dragging is not verified. The standard
`onPanStart` path is restored and hot-reloaded into the open app without a
restart. The focused title-bar suite passes 5/5 and changed-file analysis is
clean. macOS minimize/close and Windows native drag/window controls remain
open — [QA-263](../evidence/flutter/qa263-flutter-macos-native-titlebar-2026-10-04-001.json),
[QA-281](../evidence/flutter/qa281-flutter-desktop-window-chrome-macos-drag-2026-10-05-001.json).
The Windows 2022 runner passed app/vendor tests and analysis in attempt 1, but
the distribution build was cancelled by a newer master push. Attempt 2 was also
cancelled during Flutter SDK setup by a newer master push. Attempt 3 passed app/
vendor tests, analysis, release-publisher tests, and the Windows x64 distribution
build; the 25.9 MB artifact was retained —
[workflow run](https://github.com/Egkurilov/BOOHTACORD/actions/runs/37190446718).
Native Windows drag/window-control acceptance is still required before closing
FV2-018.

Follow-up: the macOS native green traffic-light zoom action is now verified in
both directions on the live window: it expands to the display-sized layout and
restores the original 1440×900 size without restarting the app — [QA-263](../evidence/flutter/qa263-flutter-macos-native-titlebar-2026-10-04-001.json).

On 2026-10-05, a test-first regression found that the root app passed the
server's guild name to both `MaterialApp.title` and `DesktopWindowChrome`, so a
guild named “Bootybay” replaced the requested BOOHTACORD desktop brand. Both
desktop title sources now remain `BOOHTACORD` regardless of guild metadata. The
regression was observed red then green; all six focused desktop-chrome tests,
changed-file analysis and a macOS Debug build pass —
[QA-292](../evidence/flutter/qa292-flutter-desktop-brand-title-2026-10-05-001.json).
The existing Mac app is currently on its startup session-error screen, so no
post-fix live screenshot or app restart was attempted. Native macOS drag and
Windows visual acceptance remain open.

macOS remote-stream discovery now distinguishes an active publication from a
subscribed video track. With manual subscriptions, a live publication may have
no attached track after thumbnail sampling; it must still expose the Watch
screen action and screen choice. Selection shows connecting until the track
arrives; after subscription Flutter now keeps an accessible first-frame status
over the canvas until the renderer reports a frame, matching the web viewer
instead of leaving an unexplained black stage. The discovery regression is
recorded in [QA-201](../evidence/flutter/qa201-macos-unsubscribed-screen-discovery-2026-10-01-001.json);
the first-frame state and macOS build are covered by
[QA-205](../evidence/flutter/qa205-flutter-screen-viewer-first-frame-state-2026-10-02-001.json).
The macOS/Darwin callback now means a pixel buffer was actually uploaded to
Flutter's texture, not merely that WebRTC delivered a frame to the native
renderer — [QA-206](../evidence/flutter/qa206-macos-texture-first-frame-upload-2026-10-02-001.json).
After the user reported that a browser-visible stream became black on switching
to the Flutter macOS client, source review found a pending texture-frame gate
that could survive track replacement. It now resets under the renderer lock in
both shared Darwin and macOS copies; a regression failed before the fix, all 20
plugin tests pass, and macOS Debug builds — [QA-209](../evidence/flutter/qa209-macos-renderer-track-replacement-2026-10-02-001.json).
This is a plausible cause, not yet a reproduced diagnosis. Live
appearance/playback/unpublish acceptance remains open as FE-61.

FE-69 screen-audio parity was runtime-checked on Android Emulator API 35 with
the current Web/Mac-published stream. The emulator had an older signed APK
(`1.0.23+2037`); after an in-place update to `1.0.25+2039`, Flutter recognized
the screen-audio track and exposed its mute and 0–200% gain controls. The
receiver UI changed to 50% and 0%, mute toggled, and the zero-volume enable
action restored 100%; the publisher was left running and the Android test
listener left the room afterward — [QA-233](../evidence/flutter/qa233-flutter-screen-audio-live-emulator-2026-10-02-001.json).
The emulator's audible output was not directly captured, so verify the actual
audible effect of mute and gain before closing FE-69. On auto-joining the
voice channel, the Android mic control was initially enabled; it was muted
immediately and remained muted until the test listener disconnected.

On 2026-10-03, a paired current-source Android Emulator API 35 → macOS Debug
full-display test established that local capture and preview work, but did not
establish remote publication: Android showed a non-black preview while its
sender diagnostics remained at 0 FPS / 0 kbit/s, and the connected Mac did not
discover a remote screen publication or expose Watch screen. Android WebRTC
logs counted captured frames but showed the send stream inactive; receiver
counters were therefore unavailable. Both clients left the room and
MediaProjection was cleared. This leaves FE-52/59/61 open and makes publication
discovery the next diagnostic step — [QA-235](../evidence/flutter/qa235-android-emulator-current-source-screen-publication-2026-10-03-001.json).

The Flutter first-frame gate also rejects delayed callbacks from a previously
selected track after the viewer switches sources. A test failed before the fix;
the full suite (409), macOS Debug build, and Android arm64 Debug build pass —
[QA-210](../evidence/flutter/qa210-flutter-stale-screen-frame-callback-2026-10-02-001.json).
This keeps the new source's loading state honest but does not prove physical
pixels are displayed; FE-59/61 still require live acceptance.

The macOS/Darwin renderer also scopes queued first-frame events to the track
generation that uploaded the pixel buffer. If a track is replaced before its
main-queue event is delivered, that stale event is now ignored; the regression,
all 21 WebRTC package tests, and a macOS Debug build pass —
[QA-211](../evidence/flutter/qa211-macos-renderer-track-generation-2026-10-02-001.json).
This closes another renderer-state race but still does not prove that the new
track's decoded frames become visible on a real Mac; keep FE-61 open pending a
paired live source-switch test.

Android MediaProjection now emits low-frequency, content-free diagnostic events
for capture startup, Android's captured-content visibility callback, Android
projection stop, and normal app teardown — [QA-208](../evidence/flutter/qa208-android-projection-diagnostic-events-2026-10-02-001.json).
These help distinguish an app-only capture becoming hidden from a stopped
projection; they do not establish why Android hid content or prove receiver
playback. The user's Calculator test was no longer active at the read-only snapshot
(MediaProjection was null, the process was alive, and no foreground service or
retained MediaProjection system log was present). Android plugin unit tests and
Java compilation pass with the installed JDK 17. FE-59/61/64 remain open for a
paired live run.

On 2026-10-02, Android Emulator API 35 / app `1.0.23+2035` passed a single-app
Clock capture: the local viewer showed a non-black portrait frame after returning
to BOOHTACORD, and MediaProjection plus the foreground service survived a muted
10-second background/resume. Stop/leave cleared the projection and service.
Five focused Flutter capture/thumbnail lifecycle tests passed —
[QA-224](../evidence/flutter/qa224-android-emulator-app-only-share-resume-2026-10-02-001.json).
This is emulator-only and had no paired receiver, so it does not close FE-59 or
FE-64's remote playback/publication checks.
That run also logged a successful local thumbnail capture followed by
`captureFailed` about 8.3 seconds later. The large preview remained visible, but
the portrait source was nearly blank in the participant strip; Flutter uses
`BoxFit.cover` and web uses `object-fit: cover`, so useful crop and refresh
parity need a targeted comparison before changing the presentation.

On 2026-10-04, a paired signed Android Emulator API 35 (`1.0.28+2047`) → existing
macOS-client run successfully published and rendered the single-app Clock
Stopwatch at the receiver. The complete 576×1280 frame was visible at 14 FPS;
receiver diagnostics reported 15 decoded FPS, 143.1 kbit/s, 0% loss, and 6 ms
jitter. Stopping the share removed the remote publication and cleared
MediaProjection; both clients returned to prejoin — [QA-257](../evidence/flutter/qa257-android-macos-screen-share-live-2026-10-04-001.json).
This confirms Android→Mac playback but does not reproduce the browser-publisher →
macOS-black-screen source switch. The installed release predates the new
diagnostic milestones, so sender/receiver event correlation remains open under
FE-61.

Vue (`clients/web/src`) is the product reference. The Flutter clients for macOS,
Windows and Android must match its user-visible behavior, information
hierarchy, copy, states and design tokens while using the same API, realtime,
ACL and LiveKit contracts. Platform-specific window chrome and permission
prompts are outside the visual comparison; product controls and resulting
states are not.

## Current parity map

This parity map began from a 2026-10-02 source audit and has follow-up records
through 2026-10-05, including the Design V2 slices above. Older rows below still
contain explicit historical gaps; re-check current Flutter/web source and the
linked evidence before treating a stale status as current. Do not use this map
as a substitute for reading the implementation.

## Android login IME follow-up (FE-57)

The reported first-character keyboard dismissal did not reproduce on the
Android 15 API 35 emulator with Gboard: after entering the first character and
then additional characters in the isolated login package, the field retained
focus and `mInputShown` remained true. The existing Flutter auth widget test
also passed while simulating app-state rebuilds and continued IME composing
updates. This is only emulator evidence; Samsung/One UI on a physical device
and the separate screen-share retry scenario remain open —
[QA-271](../evidence/flutter/qa271-android-login-ime-emulator-2026-10-05-001.json).

Flutter startup now bounds API/session storage initialization, platform
initialization, current-session lookup and account preparation with one
retryable 20-second deadline, preventing a native initialization stall from
leaving the app on an indefinite launch splash — [QA-216](../evidence/flutter/qa216-macos-bounded-startup-initialization-2026-10-02-001.json).
Runtime retry and session restoration on a signed macOS release remain open.

The web prejoin roster uses one long-lived `EventSource` per workspace. The
server sends heartbeat comments, reconciles roster snapshots every five
seconds, and revalidates the session cookie every 10 seconds without closing
the connection. It emits only changed snapshots, so a missed LiveKit webhook
does not leave the roster stale indefinitely. A revoked session emits
`session-expired`, which closes the source and follows the existing session
expiry path. The first `CONNECTED` transition of the separate
workspace WebSocket must not force a second roster stream immediately after
mount. That redundant initial reopen is gated now; a later WebSocket recovery
still refreshes the roster, and calling the roster manager's `start()` twice is
idempotent — [QA-144](../evidence/flutter/qa144-web-roster-sse-initial-reconnect-2026-09-30-001.json).
Live browser verification of one persistent stream and the session-expired
path is still open. On 2026-09-30 the
authenticated production browser prejoin for `SHARE_TEST` first showed “состав
недоступен” and “Не удалось обновить состав комнаты. Повторяем попытку”; a later
automatic refresh cleared the error and showed the room as empty. The user-provided
Flutter screenshot showed the same failure state. A local Flutter regression now
passes for 503 → retry → successful empty snapshot, but live Flutter retry and
populated roster acceptance remain unverified. No voice join or microphone was
started. The cause remains unknown;
correlate a failure with server/LiveKit diagnostics and verify populated/empty/error
snapshots and recovery on both clients —
[QA-148](../evidence/flutter/qa148-production-prejoin-roster-recovery-2026-09-30-001.json),
[QA-18](../evidence/flutter/qa18-prejoin-voice-roster-2026-09-27-001.json).

An uncommitted follow-up now keeps the authenticated stream open, emits heartbeat
comments, revalidates its original session every 10 seconds, and sends
`session-expired` when that session is revoked or replaced. Focused backend and
Flutter tests pass; web typecheck, all 760 tests, and production build pass.
Deployment, live browser/Flutter reconnect,
two-account ACL/privacy checks, and production error correlation remain open —
[QA-231](../evidence/backend/qa231-long-lived-voice-roster-sse-session-revalidation-2026-10-02-001.json).

On initial topology load, the web client now selects the first TEXT channel in
category/channel order, matching Flutter. Existing TEXT/VOICE/DM selection is
preserved while valid; a removed channel falls back to the first available
TEXT channel, if any — [QA-145](../evidence/flutter/qa145-web-default-text-channel-2026-09-30-001.json).

The Design V2 screen viewer now uses the full available stage for video and a
12 px clipped canvas. Its source label matches the web copy «Ваш экран» /
«Экран …», live badge, desktop 16/40 px inset/height and compact 8/28 px geometry;
long publisher names are constrained before the trailing viewer controls.
Geometry tests, the full 467-test Flutter suite, changed-file analysis, and
Android/macOS Debug builds pass. Windows build, matched screenshots, and device
runtime acceptance remain open — [QA-241](../evidence/flutter/qa241-flutter-design-v2-screen-stage-2026-10-04-001.json).

After web commit `10a723a9` revised compact stream-card padding and raised the
thumbnail from 48 to 50 px, Flutter now uses 124 px selected / 126 px
unselected thumbnail widths, matching its 128×80 px cards after border
compensation. The regression failed before the fix at 118×48 px; focused rail
tests, full suite, analyzer, and Android/macOS Debug builds pass — [QA-242](../evidence/flutter/qa242-flutter-design-v2-compact-screen-rail-2026-10-04-001.json).
FV2-013 aligns compact workspace navigation/member actions to the web's
44×44 px controls while retaining 48×48 px desktop navigation and existing
callbacks. The baseline test observed the prior 40×48 px hamburger; the focused
geometry test, full 468-test Flutter suite, targeted analyzer, and Android/macOS
Debug builds pass — [QA-243](../evidence/flutter/qa243-flutter-design-v2-compact-voice-header-2026-10-04-001.json).
FV2-014 now aligns the admin member headings and compact workspace header with
web: member page title 22/28 px compact and 24/32 px desktop at weight 600,
section title 20/28 px, account name 16/20 px, and 44×44 compact navigation and
close targets. Existing refresh and permission callbacks are preserved —
[QA-245](../evidence/flutter/qa245-flutter-design-v2-admin-typography-header-2026-10-04-001.json).
Windows, paired screenshots, and platform runtime acceptance remain open.

FV2-011 aligns the viewer mute/gain controls and percentage: desktop toolbar row
40 px, compact row 48 px within the 56 px strip. Flutter keeps the 0–200% gain
slider available on compact Android even though web hides it there, preserving
the requested mobile volume adjustment. Deafen and audio-state ownership are
unchanged — [QA-244](../evidence/flutter/qa244-flutter-design-v2-screen-audio-controls-2026-10-04-001.json).
FV2-015 now sets the auth eyebrow to 16 px at compact widths and 18 px on
desktop, the title to weight 600, and the submit label to weight 500, matching
the current web presentation. Two widget checks cover 390/1440 px; the full
Flutter suite (484), targeted analyzer, macOS Debug build and Android Debug
build pass. Android API 35 visually confirmed the login card in an isolated
debug package without modifying the installed release session. The macOS app
remained open after hot reload, but its auth screen was not opened because UI
automation lacks Accessibility permission — [QA-246](../evidence/flutter/qa246-flutter-design-v2-auth-typography-2026-10-04-001.json).
FV2-016 adds the loaded-account count, name/login search, and role filter to
the existing Flutter member directory. It filters only loaded accounts, keeps
pagination and the current save/block/reset handlers, and has focused unit and
widget regressions. The Android API 35 release-signed emulator run visually
verified the compact 44 px controls, selected value and role menu; macOS Debug
build passes, while Admin-screen navigation remains pending Accessibility
permission. A follow-up found that the 81 px compact selected label could wrap
and then ellipsize; `FittedBox(scaleDown)` now keeps the complete short label
on one line. API 35 visually verified `Участ.` on version `1.0.28+2047`;
desktop control geometry remains covered at 1440 px —
[QA-247](../evidence/flutter/qa247-flutter-design-v2-admin-member-filters-2026-10-04-001.json),
[QA-253](../evidence/flutter/qa253-flutter-compact-role-label-fit-2026-10-04-001.json).

FV2-017's R14 guild navigation header, search, tabs and profile footer have
passed local focused geometry/action tests, the full 484-test suite, and
targeted analysis. Android API 35 and the already-open macOS client were
visually checked without resetting session state; both show the guild title
and count, separate search, channel/DM tabs and account footer. Windows CI and
artifact startup passed earlier, but Windows-native visual capture remains
open — [QA-248](../evidence/flutter/qa248-flutter-design-v2-guild-navigation-2026-10-04-001.json).

Flutter's voice prejoin header now mirrors the web copy for roster loading,
unavailable, empty and populated states instead of showing a static invitation
that diverged from the room card. The roster subtitle remains visible even when
administrator admission is closed. For a closed channel, Flutter also mirrors
web's dedicated status message, hides the roster/prejoin card and join controls,
and offers Leave while already connected; a selected stream viewer is retained.
Widget regressions cover loading, unavailable, empty and populated states, an
unavailable roster in a closed channel, and both disconnected/connected closed
states; full Flutter tests/analyzer pass —
[QA-169](../evidence/flutter/qa169-flutter-prejoin-roster-header-copy-2026-10-01-001.json),
[QA-170](../evidence/flutter/qa170-flutter-closed-channel-roster-header-2026-10-01-001.json),
[QA-171](../evidence/flutter/qa171-flutter-closed-voice-admission-parity-2026-10-01-001.json).

| Area | Web reference | Flutter now | Remaining gap |
| --- | --- | --- | --- |
| Authentication and maintenance | `identity/AuthenticationLanding.vue`, `maintenance/MaintenanceBanner.vue`, `identity/PasswordResetCompletion.vue` | Auth page follows web eyebrow/title/copy, 440 px max card, responsive padding, labeled fields and full-width submit [QA-42](../evidence/flutter/qa42-auth-layout-web-parity-2026-09-28-001.json); login accepts a nonempty existing password while registration enforces the backend's 12–128 Unicode-code-point range [QA-43](../evidence/flutter/qa43-auth-password-validation-web-contract-2026-09-28-001.json); switching login/register clears the prior auth error as on web [QA-44](../evidence/flutter/qa44-auth-mode-error-reset-2026-09-28-001.json); the auth mode selector now matches the web's 48 px tablist/40 px controls and exposes tablist/tab roles with selected state [QA-82](../evidence/flutter/qa82-auth-tabs-web-parity-2026-09-28-001.json); app version and build number are visible before login and in profile settings, with a test ensuring they match `pubspec.yaml` [QA-147](../evidence/flutter/qa147-android-visible-app-version-2026-09-30-001.json); native PlatformException errors now expose bounded code/message while redacting credential-like values and omitting details [QA-59](../evidence/flutter/qa59-android-auth-platform-exception-diagnostics-2026-09-28-001.json); macOS uses a versioned legacy Keychain service after a startup sample traced a renewed stall to `SecItemCopyMatching`; a fresh debug process restored an existing signed-in workspace session, and a macOS integration test proved plugin-level write/read/delete using a disposable QA key [QA-99](../evidence/flutter/qa99-macos-keychain-service-rotation-2026-09-29-001.json), [QA-113](../evidence/flutter/qa113-macos-keychain-integration-roundtrip-2026-09-29-001.json); stable Android focus nodes/field keys and no login autocorrect/suggestions; native server/reset actions retained; maintenance banner follows web min-height 44, 14/20 text, 12/16 padding and natural wrapping [QA-41](../evidence/flutter/qa41-maintenance-banner-web-geometry-2026-09-28-001.json), explicitly disables text decoration and no longer inserts workspace safe-area inset below itself [QA-67](../evidence/flutter/qa67-maintenance-banner-android-spacing-2026-09-28-001.json); protected 401 clears private workspace; reset completion from pasted same-origin link [QA-23](../evidence/flutter/qa23-android-ime-screen-share-2026-09-27-001.json) | Reproduce the reported Android login PlatformException on Samsung and diagnose from sanitized device logs; confirm first-character/multi-character Gboard entry; verify maintenance/header alignment against a physical Android screenshot; verify a new macOS session-cookie write and one-time re-login from the legacy Keychain service [QA-99](../evidence/flutter/qa99-macos-keychain-service-rotation-2026-09-29-001.json); automatic HTTPS app-link association, full focus/error and screenshot parity |
| Application identity | `clients/web/index.html` retains the `Voice Platform` page title and now uses the supplied artwork as favicon [QA-74](../evidence/flutter/qa74-web-favicon-brand-parity-2026-09-28-001.json) | Provided BOOHTACORD artwork is retained as the source image and applied to Android launcher mipmaps, macOS AppIcon assets and a seven-size Windows ICO [QA-73](../evidence/flutter/qa73-application-icon-2026-09-28-001.json); Android 8+ places the supplied composite artwork on the full-bleed adaptive background instead of shrinking its built-in rounded square inside the safe-zone foreground; pre-26 density icons remain unchanged [QA-77](../evidence/flutter/qa77-android-adaptive-launcher-icon-2026-09-28-001.json); an Android themed-icon monochrome `B` layer now compiles into the adaptive resource without changing the standard full-color icon [QA-133](../evidence/flutter/qa133-android-themed-launcher-icon-2026-09-29-001.json); Pixel 7 default/circle launcher visual acceptance passes with no extra white inner frame | Verify themed-icon rendering on Pixel with themed icons enabled; verify installed icon rendering on macOS/Windows; decide whether the web page title should also change from `Voice Platform` to `BOOHTACORD` |
| Desktop packaging | GitHub Actions macOS/Windows CI and release assets | The last universal macOS Release evidence is 1.0.13+18 for arm64+x86_64; current-source Debug 1.0.15+20 was rebuilt and reached SHARE_TEST prejoin after more than six minutes [QA-160](../evidence/flutter/qa160-macos-debug-restart-2026-09-30-001.json). The release packager safely re-seals a stale outer ad-hoc CodeResources hash after Flutter/Xcode changes nested `App.framework`, preserves existing entitlements, rejects invalid Developer ID signatures without replacing them, and verifies/package-checks a 40.1 MB ZIP under the 95 MB asset ceiling [QA-153](../evidence/flutter/qa153-macos-release-ad-hoc-seal-recovery-2026-09-30-001.json); prior current-source build evidence [QA-151](../evidence/flutter/qa151-macos-release-current-source-build-2026-09-30-001.json). GitHub CI run #81 passed Windows tests/analyze/Release packaging and Flutter/LiveKit/WebRTC tests/analyze/Android debug build [QA-194](../evidence/flutter/qa194-ci-run-b0fe7a4-windows-flutter-2026-10-01-001.json) | The macOS CI/release workflows remain manual-only while the self-hosted macOS runner is being migrated. Developer ID/notarization, normal-latency app startup/session persistence, save-dialog behavior and voice/screen-share runtime acceptance remain open; Windows runtime screen/audio acceptance remains open |
| Workspace shell | `workspace/WorkspaceApp.vue`, `WorkspaceMain.vue`, `useWorkspaceDrawers.ts` | Sidebar/member drawers and scrim on compact layouts; medium member overlay; wide member aside; search stays beside the active conversation; modal search overlay below 1280 px and in wide voice-stage layout; Android and iOS compact layouts support edge swipes to open/close navigation and member panels [QA-78](../evidence/flutter/qa78-android-ios-mobile-swipes-2026-09-28-001.json); Android grants the currently enabled drawer edge a narrow system-gesture exclusion zone, leaving Back available elsewhere; Pixel 7 acceptance confirms both edge drawers open from the display boundary while Back works outside the centered exclusion [QA-125](../evidence/flutter/qa125-android-edge-swipe-navigation-2026-09-29-001.json); drawer/search focus scopes, Escape/close behavior and focus return | Exact breakpoint behavior, admin/profile/dialog focus, accessibility announcements and screenshot comparison; iOS gesture acceptance remains open |
| Profile | `identity/ProfileSettings.vue`, `identity/current_profile.ts`, `workspace/WorkspaceUserFooter.vue` | Display name/password, authenticated private avatar rendering, PNG/JPEG upload/remove, logout flow with pending/error state; profile load failures are isolated from general workspace errors, with accessible loading/error live-region states and retry-clearing behavior [QA-45](../evidence/flutter/qa45-profile-loading-error-web-parity-2026-09-28-001.json); own-profile validation now matches web/backend Unicode code-point rules without trimming display names or applying a grapheme-count input cap; mutation feedback is announced, and opening the profile focuses its semantic heading [QA-48](../evidence/flutter/qa48-profile-mutation-validation-focus-web-parity-2026-09-28-001.json); closing profile/audio/admin settings restores keyboard focus to the opening control [QA-63](../evidence/flutter/qa63-settings-panel-focus-return-2026-09-28-001.json); layout follows web CSS max-width 720/480, centered/responsive insets, 64 px avatar, 16 px title and section separators; panel toolbar has one semantic page heading and breakpoint-matched actions [QA-49](../evidence/flutter/qa49-profile-geometry-web-parity-2026-09-28-001.json); Android notifications use a packaged, shrinker-retained monochrome icon instead of the missing `ic_launcher` drawable that caused the reported `invalid_icon` [QA-75](../evidence/flutter/qa75-android-profile-notification-icon-2026-09-28-001.json); native macOS/Windows/Android notification preference uses generic previews, OS permission handling, hidden-app delivery, unread increase and per-account deduplication [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json) | Matched screenshots; Samsung/Gboard and real screen-reader keyboard acceptance; real macOS notification permission/delivery, Windows toast registration, and Android 13+ permission/background delivery acceptance |
| Channels | `channel/ChannelNavigation.vue`, `conversation/TextConversation.vue`, `text_read_gate.ts`, `voice_navigation_presence.ts`, `voice/VoiceRoomRoster.vue` | Ordered categories, text/voice selection, caller-local unread/mention badges, newest visible message cursor advancement; web selects the first TEXT channel on initial topology load, matching Flutter [QA-145](../evidence/flutter/qa145-web-default-text-channel-2026-09-30-001.json); member profile popover constrains its identity column, clamps long display names to two lines and ellipsizes long logins like Flutter [QA-146](../evidence/flutter/qa146-web-member-popover-long-login-2026-09-30-001.json); active voice channel now shows live member count, mic/speaking status and screen-share indicators; prejoin/connected rosters now match web's 24 px avatars, 12 px labels, 4 px row gaps, 40 px indent, FNV palette mapping, and outlined screen-share badge [QA-36](../evidence/flutter/qa36-voice-roster-web-geometry-2026-09-28-001.json) | Matched screenshots and runtime comparison of active/prejoin roster at desktop breakpoints and Android portrait; admin topology controls are tracked under Administration |
| Text chat | `conversation/TextConversation.vue`, `TextHistoryList.vue`, `MessageItem.vue`, `MessageBody.vue` | Chronological cursor-paged history with scroll restoration; local-date dividers and same-author grouping; formatted bodies and safe HTTP(S) links; mention picker/sending/name display; send, reply target/preview, edit/delete and visible read cursor; unsent drafts restore per account/channel with body, reply target, uploaded attachments and mentions until logout/session expiry; optimistic/failed rows with explicit exact-payload retry reusing `client_message_id`, reconciled against server history; edit draft/mention preservation and targeted revision refresh after `409`; delete keeps the loaded window; deleted-during-edit and stale-conversation widget/state coverage; native generic notifications fire only for new unread messages while app is hidden [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json); Android touch scrolling no longer snaps back to latest during slow drags near the bottom; automatic latest correction only runs when message history changes [QA-70](../evidence/flutter/qa70-android-text-scroll-2026-09-28-001.json); prepending cursor pages in TEXT and DM preserves the visible message's screen position and does not regress the read cursor [QA-177](../evidence/flutter/qa177-text-history-scroll-anchor-2026-10-01-001.json), [QA-178](../evidence/flutter/qa178-dm-history-scroll-anchor-2026-10-01-001.json); Flutter realtime refresh merges new TEXT messages into the loaded window without resetting pagination [QA-179](../evidence/flutter/qa179-text-realtime-history-merge-2026-10-01-001.json), with stale async loads invalidated safely during conversation navigation [QA-180](../evidence/flutter/qa180-text-history-navigation-race-2026-10-01-001.json); Android and iOS support swipe-to-reply and pull-to-refresh for text and direct messages [QA-78](../evidence/flutter/qa78-android-ios-mobile-swipes-2026-09-28-001.json); composer draft memory isolation/restore/clear tests [QA-71](../evidence/flutter/qa71-composer-draft-memory-web-parity-2026-09-28-001.json); composer now uses compact in-field `+` and mention `@` controls, with attachment and clipboard actions grouped under `+`, selected-mention chips preserved, and large labeled controls removed [QA-124](../evidence/flutter/qa124-flutter-compact-chat-composer-2026-09-29-001.json), [QA-127](../evidence/flutter/qa127-flutter-composer-action-menu-2026-09-29-001.json); Pixel 7 / Android 17 confirmed both menu actions fit above system navigation; Android TEXT/DM composers expose the soft-keyboard `Send` action and submit from it, matching web's Enter-to-send path; a hardware Shift+Enter does not trigger send [QA-156](../evidence/flutter/qa156-flutter-composer-soft-keyboard-send-2026-09-30-001.json) | Live backend mutation/retry check, physical Android scroll/read-cursor and draft-switch behavior, native notification OS delivery acceptance; matched composer/conversation screenshots and keyboard/assistive-tech acceptance remain open on macOS and Windows; confirm Gboard/Samsung IME behavior on a device (widget tests do not prove actual newline insertion) |
| Text attachments/search | `TextMessageAttachmentPicker.vue`, `TextMessageAttachments.vue`, `PublishedAttachmentCard.vue`, `ProtectedImageViewer.vue`, `TextMessageSearch.vue` | Native multi-file picker, 10 × 25 MB checks, authenticated multipart upload with per-file progress and retry preserving successful IDs; upload target captured before reading bytes; attachment-only send supported; web paste plus native Flutter `Ctrl/Cmd+V`, `Shift+Insert` and context menu read clipboard PNG into the scoped upload queue while preserving plain text [QA-21](../evidence/flutter/qa21-clipboard-image-paste-2026-09-27-001.json), [QA-22](../evidence/flutter/qa22-native-clipboard-image-paste-2026-09-27-001.json); compact composer groups file picking and clipboard paste under the in-field `+` action, while keyboard/context-menu paste remains available [QA-124](../evidence/flutter/qa124-flutter-compact-chat-composer-2026-09-29-001.json), [QA-127](../evidence/flutter/qa127-flutter-composer-action-menu-2026-09-29-001.json); protected image viewer with fit-to-window/loading/retry/unavailable states, separate authenticated save action, filename header and image alt text from the attachment filename [QA-105](../evidence/flutter/qa105-protected-image-viewer-accessibility-2026-09-29-001.json), web-matching open/close labels with desktop hover tooltip [QA-106](../evidence/flutter/qa106-protected-image-viewer-copy-2026-09-29-001.json), initial focus on close, Tab focus loop, Escape close and return to opener [QA-107](../evidence/flutter/qa107-protected-image-viewer-focus-2026-09-29-001.json), [QA-108](../evidence/flutter/qa108-protected-image-viewer-initial-focus-2026-09-29-001.json); loading and unavailable/deleted statuses use polite live regions [QA-109](../evidence/flutter/qa109-protected-image-viewer-live-status-2026-09-29-001.json); responsive viewer geometry at desktop/compact sizes and image-decode retry [QA-264](../evidence/flutter/qa264-flutter-protected-image-viewer-overlay-2026-10-05-001.json); web and Flutter use separate open/save actions; channel-scoped search and context navigation | Run native paste/permission/size, hover, and screen-reader acceptance on macOS, Windows and Android; verify protected download/ACL, server-side `UNATTACHED` cleanup and live 507/partial-upload UX [QA-20](../evidence/flutter/qa20-web-attachment-image-viewer-2026-09-27-001.json) |
| Direct messages | `direct_message/DirectMessageConversation.vue`, `DirectMessageNavigation.vue`, `DirectMessageAttachments.vue`, `PublishedAttachmentCard.vue`, `ProtectedImageViewer.vue`, `MessageBody.vue` | List/create/open, cursor-paged history with scroll restoration, send, unread/read cursor, edit/delete, formatted bodies and mention picker/name display; reply compose/preview; unsent drafts restore per account/DM with body, reply target, uploaded attachments and mentions until logout/session expiry [QA-71](../evidence/flutter/qa71-composer-draft-memory-web-parity-2026-09-28-001.json); private attachments upload with per-file progress and retry preserving successful IDs, attachment-only send, web/native clipboard paste and explicit retry into the conversation-scoped upload queue [QA-21](../evidence/flutter/qa21-clipboard-image-paste-2026-09-27-001.json), [QA-22](../evidence/flutter/qa22-native-clipboard-image-paste-2026-09-27-001.json); protected image viewer with fit-to-window/loading/retry/unavailable states and separate authenticated save action [QA-264](../evidence/flutter/qa264-flutter-protected-image-viewer-overlay-2026-10-05-001.json); upload target captured before reading bytes; DM-scoped search/context; optimistic/failed rows with explicit exact-payload retry keep the original `client_message_id` and stay in their DM; edit draft/mention preservation and targeted revision refresh after `409`; delete keeps the loaded window; new unread DMs use generic native notifications [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json) | Run native paste/retry permission acceptance on macOS, Windows and Android; verify server-side `UNATTACHED` cleanup and live 507/partial-upload UX, live backend mutation/retry check, notification OS delivery, ACL and visual QA [QA-20](../evidence/flutter/qa20-web-attachment-image-viewer-2026-09-27-001.json) |
| Members and presence | `workspace/WorkspaceMembersPanel.vue`, `GuildPresenceGroup.vue`, `MemberPopover.vue`, `identity/guild_presence.ts` | Directory grouped into online/offline/unknown sections with matching counts and inline loading/error/retry states; realtime snapshots and changes update group membership, while an unavailable feed resolves every status to unknown until a new snapshot; anchored profile popover loads authenticated member details and exposes DM, same-voice volume, and admin voice kick actions [QA-27](../evidence/flutter/qa27-member-presence-groups-2026-09-27-001.json), [QA-28](../evidence/flutter/qa28-guild-presence-realtime-2026-09-27-001.json), [QA-29](../evidence/flutter/qa29-member-profile-popover-2026-09-27-001.json); responsive popover width, right inset, row alignment, avatar and action/volume geometry now follow web CSS tokens [QA-34](../evidence/flutter/qa34-member-profile-popover-web-geometry-2026-09-28-001.json) | Verify live presence transitions against two accounts; matched visual/device acceptance for roster and popover |
| Voice connection | `voice/VoicePrejoin.vue`, `VoiceDock.vue`, `connection_store.ts`, `voice_connection_quality.ts`, `VoiceParticipantStatus.vue`, `VoiceParticipantVolumes.vue`, `voice_roster_client.ts` | Join/transfer, listener-only join, mic mute, deafen, leave, participant status cards, visible reconnect state and lease-specific revocation reasons; dock now follows web connected/reconnecting/leaving copy and state-specific hints, announces transitions, serializes deafen operations and locks pending/leave controls [QA-53](../evidence/flutter/qa53-voice-dock-deafen-web-parity-2026-09-28-001.json); authenticated prejoin roster uses a long-lived, server-pushed SSE stream with 10-second session revalidation and a session-expired event, and is shown in the prejoin card/navigation without creating a voice lease; prejoin and joining copy now match web, with live-region announcements for connection/failure and roster loading/error states [QA-52](../evidence/flutter/qa52-voice-prejoin-copy-live-region-2026-09-28-001.json), [QA-138](../evidence/flutter/qa138-voice-roster-contract-sync-2026-09-30-001.json), [QA-154](../evidence/flutter/qa154-prejoin-roster-live-status-parity-2026-09-30-001.json); connected-room header and persistent Flutter dock plus web dock show the same LiveKit connection-quality color/icon and audio RTT ping when reported, with an explicit unavailable placeholder otherwise [QA-110](../evidence/flutter/qa110-voice-connection-quality-2026-09-29-001.json), [QA-111](../evidence/flutter/qa111-web-voice-connection-quality-2026-09-29-001.json); Android now polls publisher peer-connection stats and falls back to the selected ICE candidate-pair RTT when audio `remote-inbound-rtp` feedback is absent (e.g. microphone muted), without using stale/unselected pairs [QA-122](../evidence/flutter/qa122-android-voice-ice-rtt-fallback-2026-09-29-001.json); Flutter status live-region excludes periodic ping updates to avoid repeated announcements [QA-112](../evidence/flutter/qa112-voice-quality-accessibility-macos-build-2026-09-29-001.json); the room badge now announces connecting, connected, reconnecting, leaving, disconnected and error states accurately, and hides quality/ping until connected [QA-119](../evidence/flutter/qa119-voice-connection-transition-state-2026-09-29-001.json); per-participant microphone volume 0–200% with account-scoped local preferences; PTT holds mic open and releases safely on key-up/focus loss/teardown; failed microphone capture visibly identifies the listener fallback, marks the local participant unavailable and offers VAD retry without bypassing PTT [QA-32](../evidence/flutter/qa32-voice-microphone-unavailable-fallback-2026-09-27-001.json); active room recovery is capped at the web policy's six attempts and uses matching exponential delays/jitter [QA-33](../evidence/flutter/qa33-flutter-voice-reconnect-limit-2026-09-28-001.json), [QA-86](../evidence/flutter/qa86-voice-reconnect-web-parity-2026-09-29-001.json); participant status precedence and speaking indicators now match web for muted, unavailable, deafened, speaking and in-channel states [QA-35](../evidence/flutter/qa35-voice-participant-status-web-parity-2026-09-28-001.json) | Production prejoin roster failure now reproduces on web and is also present in the user's Flutter screenshot; correlate server/LiveKit diagnostics and verify roster refresh/privacy recovery on each platform before claiming roster parity. Also test real-peer gain/PTT, reconnect timing, actual mute/deafen media and screen-reader announcements on native hardware, Android/macOS/Windows audio RTT, and exact dock/prejoin screenshots [QA-18](../evidence/flutter/qa18-prejoin-voice-roster-2026-09-27-001.json), [QA-110](../evidence/flutter/qa110-voice-connection-quality-2026-09-29-001.json), [QA-111](../evidence/flutter/qa111-web-voice-connection-quality-2026-09-29-001.json), [QA-112](../evidence/flutter/qa112-voice-quality-accessibility-macos-build-2026-09-29-001.json) |
| Active voice participant grid | `voice/VoiceParticipantVolumes.vue`, `voice/VoiceParticipantStatus.vue`, `design/voice.css`, `design/voice_participant_screens.css` | Connected-room cards follow web auto-fill columns with 160 px minimum width, 176 px minimum height, 64 px avatar and top-aligned content; screen-share badge and accessible screen-view action remain visible in the participant card [QA-65](../evidence/flutter/qa65-active-voice-grid-web-parity-2026-09-28-001.json); status stays centered and on one ellipsized line when microphone and remote audio are both disabled [QA-121](../evidence/flutter/qa121-deafened-participant-status-alignment-2026-09-29-001.json) | Matched web/Flutter screenshots at desktop and Android portrait; native VoiceOver, NVDA and TalkBack labels and touch acceptance |
| Audio settings | `voice/AudioSettings.vue`, `AudioDeviceCheck.vue`, `audio_check.ts`, `activation_store.ts`, `audio_settings_store.ts` | Account settings panel with input/output device selection, account-scoped persistence, VAD/PTT and key assignment, AGC/echo/noise controls; native device labels remain visible even without a `default` entry, the panel follows device-change events without stale scans, manual refresh stays enabled after enumeration completes and reflects pending state, and device enumeration is retried after the first successful microphone capture in case labels were permission-gated; Android adds named USB microphone inputs to WebRTC's limited device list and Android 12+ built-in, wired, Bluetooth and USB communication outputs via `AudioManager`, preserving selected route across connection and clearing it on leave/disconnect [QA-69](../evidence/flutter/qa69-android-usb-audio-routes-2026-09-28-001.json), [QA-126](../evidence/flutter/qa126-android-communication-audio-routes-2026-09-29-001.json); Android local mic test maps WebRTC input IDs such as `microphone-bottom` to AudioRecord's numeric Android device ID; Pixel 7 speech test passed [QA-128](../evidence/flutter/qa128-android-local-microphone-check-2026-09-29-001.json); Android uses the system default route instead of showing a false empty output list if enumeration is unavailable, including after an empty native `devicechange` scan [QA-149](../evidence/flutter/qa149-android-audio-empty-device-refresh-2026-09-30-001.json); narrow layouts use compact selected labels for PTT/noise selectors while preserving full options, and Android can select PTT without assigning a hardware key [QA-219](../evidence/flutter/qa219-android-ptt-settings-responsive-2026-10-02-001.json); native settings include a local microphone meter and short speaker signal matching the web check; PCM is discarded locally, never saved or sent; Android has a visible Back control and handles system Back from audio/profile/admin panels; avoids claiming native effective processing state that SDK does not expose [QA-72](../evidence/flutter/qa72-local-audio-device-check-2026-09-28-001.json) | Verify physical USB/Bluetooth hotplug and audible route switching during a voice call on Android; verify device-change notification and switching on macOS/Windows; PTT hold/release and focus/state visual comparison |
| Voice stream-start alert | `voice/VoiceDock.vue`, `stream_start_runtime.ts`, `stream_start_alert.ts`, `stream_start_chime.ts` | Newly started remote shares show a six-second live-region dock notice and a persisted, toggleable sound signal; initial room baseline and reconnect tracking avoid duplicate alerts for existing/restored shares [QA-54](../evidence/flutter/qa54-voice-stream-start-alert-web-parity-2026-09-28-001.json) | Verify LiveKit event timing and audible platform system sound on macOS, Windows and Android |
| Voice dock screen-share control | `voice/VoiceDock.vue`, `_VoiceRoom` | Persistent voice dock on Flutter and web now starts/stops local screen share; starting opens the quality setup flow, stop acts on the published track, and controls lock during join/reconnect or capture transitions [QA-55](../evidence/flutter/qa55-voice-dock-screen-share-control-2026-09-28-001.json), [QA-84](../evidence/flutter/qa84-web-screen-share-setup-parity-2026-09-29-001.json); mic, deafen and stream-alert controls expose matching action labels and pressed/toggled states [QA-58](../evidence/flutter/qa58-voice-dock-accessible-toggle-state-2026-09-28-001.json); compact Android layout reserves a fixed bottom dock with the same voice actions, available while the navigation drawer is open and without duplicating the drawer dock [QA-66](../evidence/flutter/qa66-android-mobile-voice-dock-2026-09-28-001.json); compact dock is intentionally non-expandable and omits its redundant hint/chevron; audio ping reads RTT from the paired LiveKit `remote-inbound-rtp` report instead of outbound stats [QA-120](../evidence/flutter/qa120-voice-ping-compact-dock-2026-09-29-001.json) | Accept dock touch targets, live RTT updates and state changes on a physical Android device; verify the accessible labels and toggle announcements using VoiceOver, NVDA and TalkBack |
| Android capture permissions | `android/app/src/main/AndroidManifest.xml`, `MainActivity`, `flutter_background` | Release manifest declares the MediaProjection foreground-service permission/type and omits battery-optimization exemptions [QA-56](../evidence/flutter/qa56-android-battery-permission-minimization-2026-09-28-001.json); before capture, Flutter now confirms the merged service declaration contains `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION`, while the plugin starts it using the manifest-declared type; contract test and both Kotlin Gradle modes pass [QA-212](../evidence/flutter/qa212-android-media-projection-service-readiness-2026-10-02-001.json); Pixel full-display test confirms MediaProjection and FGS survive about one minute in background and local voice screen/preview recover on resume, with clean stop [QA-222](../evidence/flutter/qa222-pixel-screen-share-background-lifecycle-2026-10-02-001.json). Separate open gap: current service does not declare microphone FGS and background voice acceptance must compare mic-muted vs mic-enabled behavior. If mic capture must continue in background, Android 14+ requires the microphone service type and `FOREGROUND_SERVICE_MICROPHONE`, and the service must start while an Activity is visible [QA-221](../evidence/flutter/qa221-android-background-microphone-fgs-gap-2026-10-02-001.json), [Android docs](https://developer.android.com/about/versions/14/changes/fgs-types-required), [background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) | Verify server-visible room presence/publication with a paired receiver, encoded/decoded frame counters and app-only capture; separately test microphone continuity with mic muted and enabled before changing the service declaration |
| Receiver diagnostics layout | `ScreenReceiverDiagnosticsPanel.vue`, `voice_viewer_reference.css` | Native diagnostics use the web's compact 36 px summary and raised 288 px popover rather than consuming viewer column height; panel scrolls, flips above near viewport bottom, closes on outside tap/Escape, and remains within 360 dp width [QA-57](../evidence/flutter/qa57-screen-diagnostics-popover-web-parity-2026-09-28-001.json) | Compare matched viewer screenshots and verify populated receiver metrics on physical devices |
| Screen sharing | `voice/ScreenViewer.vue`, `ScreenDiagnosticsPanel.vue`, `screen_viewer_controller.ts`, `screen_client_reporter.ts` | Like Flutter, the local published screen opens automatically as a muted preview when no stream is selected; closing it returns to the participant room. The viewer rail can switch between local preview and remote streams with an accessible selected state; remote receiver diagnostics sample decoded frames, bitrate, loss and jitter every two seconds, with unavailable RTT shown truthfully; Flutter scopes async stats reads to the selected track generation so a delayed old-track response cannot block sampling or clear the active sample lock [QA-140](../evidence/flutter/qa140-receiver-diagnostics-track-generation-2026-09-30-001.json); packet loss now uses a rolling ten-second receiver-stat window and is shown as a percentage on web and Flutter [QA-134](../evidence/flutter/qa134-realtime-voice-roster-screen-thumbnails-2026-09-30-001.json); native viewer has a fullscreen overlay, Escape/exit control, spaced diagnostics and explicit receiver-stat read status; anonymous sender/receiver reports and admin diagnostics include bounded encoded/received frame width and height for source-versus-peer comparison [QA-50](../evidence/flutter/qa50-screen-share-frame-dimensions-2026-09-28-001.json); screen-audio level 0–200% with account-scoped local preference and truthful no-audio/deafened states; custom source picker previews/screens/windows and explicit selection on desktop; web and Flutter now expose the same nine 720/1080/1440p × 15/30/60 FPS profiles and send matching capture dimensions, frame-rate, bitrate and track labels; the selected web profile is shared by room and dock, with the same pre-capture quality dialog, browser chooser guidance and segmented controls [QA-83](../evidence/flutter/qa83-screen-share-profile-web-parity-2026-09-29-001.json), [QA-84](../evidence/flutter/qa84-web-screen-share-setup-parity-2026-09-29-001.json); Android compact layout keeps quality labels on one line and stacks them above full-width selectors, with a scrollable setup body and fixed action footer at 360 dp [QA-31](../evidence/flutter/qa31-android-share-quality-compact-layout-2026-09-27-001.json); at 320 dp, both quality controls can be scrolled into view while the start action remains available [QA-76](../evidence/flutter/qa76-android-screen-share-picker-320dp-2026-09-28-001.json); Android shows setup and permission guidance without a desktop source list [QA-24](../evidence/flutter/qa24-screen-share-quality-picker-2026-09-27-001.json); Android publication cleans up an unpublished capture track on failure and surfaces SDK detail [QA-23](../evidence/flutter/qa23-android-ime-screen-share-2026-09-27-001.json); Windows now derives the selected screen/window's native size from its JPEG preview and applies the profile's aspect-preserving RTP encoder scale before publishing [QA-90](../evidence/flutter/qa90-windows-screen-share-profile-cap-2026-09-29-001.json); desktop native start failure now rejects `getDisplayMedia` and rolls back tracks/audio for every post-audio setup failure [QA-98](../evidence/flutter/qa98-windows-screen-capture-start-failure-2026-09-29-001.json), [QA-103](../evidence/flutter/qa103-desktop-screen-share-rollback-2026-09-29-001.json); macOS legacy fallback now captures the display selected in the source picker rather than silently switching to the primary display [QA-91](../evidence/flutter/qa91-macos-legacy-selected-screen-source-2026-09-29-001.json); own published screen can be reopened from the participant card; Android sends bounded anonymous sender FPS/bitrate/RTT while sharing [QA-19](../evidence/flutter/qa19-android-sender-metrics-2026-09-27-001.json) | Windows Release compilation now passes on GitVerse [QA-81](../evidence/flutter/qa81-gitverse-windows-runner-ci-2026-09-29-004.json); still verify Windows screen/window sources, minimized/foreground failures, preview updates and actual capture; measure profile/network behavior on Windows; verify macOS 12 selected-screen capture, Android receiver crop/metrics/OS stop and full remote frame in all viewers; Pixel QA-197 on `1.0.18+2027` fired `first_swap_buffers` and showed a fresh Calculator thumbnail, but the large local preview remained black. Therefore EGL swap is not sufficient: investigate Flutter texture/compositor path. No paired receiver was used; matched setup/viewer screenshots remain open [QA-17](../evidence/flutter/qa17-voice-viewer-mobile-navigation-2026-09-27-001.json), [QA-196](../evidence/flutter/qa196-pixel7-app-only-preview-renderer-2026-10-01-001.json), [QA-197](../evidence/flutter/qa197-android-preview-render-event-2026-10-01-001.json) |

| Screen preview A/B follow-up | `SurfaceTextureRenderer.java`, Android MediaProjection visibility bridge, [QA-197](../evidence/flutter/qa197-android-preview-render-event-2026-10-01-001.json), [QA-198](../evidence/flutter/qa198-pixel7-preview-impeller-ab-2026-10-01-001.json), [QA-199](../evidence/flutter/qa199-pixel7-preview-surfacetexture-ab-2026-10-01-001.json), [QA-200](../evidence/flutter/qa200-android-screen-preview-egl-resize-barrier-2026-10-01-001.json), [QA-220](../evidence/flutter/qa220-android-screen-preview-lifecycle-current-head-2026-10-02-001.json), [QA-225](../evidence/flutter/qa225-android-app-only-hidden-source-feedback-2026-10-02-001.json) | Pixel A/B found black local app-only preview across both texture backends and Impeller settings. Source review found a potential race when resizing the Flutter surface before asynchronous EGL teardown completes; a release barrier and unit tests were added. Emulator API 35 / `1.0.23+2036` now confirms that switching away from the selected app delivers the track-scoped Android visibility event and replaces the indefinite first-frame spinner with a truthful hidden-source explanation; stop/leave cleanup passed. | Verify the visible app-only preview on physical Pixel, then verify remote publication, decoded pixels, sender/receiver counters and crop with a paired browser/macOS client. Keep FE-59 open. |
| Search | `search/WorkspaceSearchPanel.vue`, `SearchPanel.vue`, chat search components | Global/channel/DM search in a responsive side panel while preserving the active conversation; revised web target: 380 px desktop rail at ≥1280 px and full-viewport compact overlay with 44 px close target; wide voice stage retains its modal; cursor pagination; server-centered context and return to origin; stale topology refresh; Ctrl/Cmd+K, Escape and search-focus restoration [QA-61](../evidence/flutter/qa61-search-drawer-width-parity-2026-09-28-001.json). Current Flutter presentation follow-up is FV2-019: scope/Enter row, hidden submit/status, result hierarchy/avatar/query highlight | Matched web/Flutter screenshots, device screen-reader acceptance and parity for less common loading/error states |
| Administration | `workspace/AdminPanel.vue`, `channel/AdminTopologyControls.vue`, `AdminMembersSection.vue`, `AdminAuditSection.vue`, `AdminMediaDiagnostics.vue` | Admin-only Members/Channels/Audit/Media tabs; Flutter exposes the section navigation and each selected section as web-equivalent tablist/tab semantics with selected state [QA-101](../evidence/flutter/qa101-admin-section-tab-semantics-2026-09-29-001.json); cursor-paginated directory with preserved role/block drafts and save; member count plus loaded-page name/login and role filters now match web's compact/desktop control geometry (44 px height; 81/121 px role selector) without changing pagination or ACL [QA-247](../evidence/flutter/qa247-flutter-design-v2-admin-member-filters-2026-10-04-001.json); initial Members/Audit loading copy now matches web and is announced through a polite live region [QA-102](../evidence/flutter/qa102-admin-loading-live-regions-2026-09-29-001.json); per-row focus restoration and accessible error/success; the native panel initially focuses its semantic heading [QA-64](../evidence/flutter/qa64-admin-heading-focus-accessibility-2026-09-28-001.json); expiring reset-link result/copy/close; same-voice admin kick; category/channel mutations and confirmations with stale-revision recovery; cursor-paged audit without message content; Media tab reads the same bounded, anonymous `/admin/screen-metrics` contract, polls only while selected/foregrounded and provides refresh/empty/error states. Backend route tests prove anonymous 401, MEMBER 403, ADMINISTRATOR 200 [QA-100](../evidence/flutter/qa100-admin-media-diagnostics-2026-09-29-001.json) | Verify role ACL against live sessions; matched screenshot comparison across all four tabs; VoiceOver/TalkBack acceptance |

Protected image viewer runtime follow-up (FV2-022): current Android API 35
(`1.0.29+2062`) and macOS Debug both show the complete image, separate download
action and responsive viewer controls; Android Back and macOS Escape return to
Text. Windows visual acceptance remains pending —
[QA-275](../evidence/flutter/qa275-flutter-protected-image-viewer-runtime-2026-10-05-001.json).

Android maintenance-banner safe-area follow-up (FV2-026): an API 35 runtime
screen showed the maintenance copy sharing the status-bar area with the clock
and system icons. Flutter now wraps the root content in a top SafeArea only
while maintenance is active; the widget regression checks both the top inset
and the zero-gap transition to the workspace header. The focused analyzer is
clean and the full Flutter suite passes (585 tests). Android release
`1.0.30+2065` is installed. A fresh 390×800 Flutter test capture visually
confirms the 48 dp safe area, warning-color banner and adjacent header, but the
host renderer shows Cyrillic fallback squares even with Inter/MaterialIcons
loaded, so it proves geometry/colors only. Current Android and macOS screens do
not show maintenance, leaving active-branch device visual acceptance NOT_RUN.
See
[QA-276](../evidence/flutter/qa276-flutter-maintenance-banner-status-inset-2026-10-05-001.json).

Android text-history scroll chrome follow-up (FV2-028): the widget regression
records header and composer bounds around a vertical history gesture and
asserts that the navigation drawer stays closed. The focused test, changed-file
analyzer, and full Flutter suite (585 tests) pass. A controlled Android API 35
gesture on release `1.0.30+2065` visibly moved the message list to older history
while keeping the header and composer on-screen; UIAutomator confirmed the
header subtitle and composer bounds and no open navigation drawer. No message
was sent or edited; read-cursor state was not inspected. FV2-028 is accepted;
history pagination and server read-cursor checks remain open under FV2-002 —
[QA-278](../evidence/flutter/qa278-flutter-text-scroll-chrome-android-2026-10-05-001.json).

TEXT history overlap follow-up (FV2-031): web merges cursor pages by message ID
and keeps the row with the greatest revision. Flutter's older-page merge now
uses the same rule instead of always keeping the already-loaded row. A
test-first AppState regression reproduced revision 1 winning over an overlapping
revision 2 before the fix. The focused AppState suite passes 50/50, the full
Flutter suite passes 621/621, and changed-file analysis is clean. No web, API,
read-cursor or server behavior changed; live read-cursor and device acceptance
remain open under FV2-002 —
[QA-284](../evidence/flutter/qa284-flutter-text-history-revision-overlap-2026-10-05-001.json).

TEXT/DM history ordering follow-up (FV2-032): web's rendered chronology uses
creation time followed by ascending message ID when multiple rows share the
same timestamp. Flutter previously sorted only by creation time, so a response
in the opposite ID order stayed inconsistent. Test-first TEXT and DM
regressions reproduced the drift; both Flutter history reconcilers now apply
the deterministic `(createdAt, id)` order. No API, cursor, read-state or
server behavior changed — [QA-285](../evidence/flutter/qa285-flutter-history-equal-timestamp-order-2026-10-05-001.json).

DM history overlap follow-up (FV2-033): Flutter's older-page merge used
`putIfAbsent`, retaining the loaded row even when the cursor page carried a
higher revision. A test-first AppState regression reproduced revision 1
winning over revision 2; the merge now uses the greatest revision, matching
web and TEXT. No API, cursor, read-state or server behavior changed —
[QA-286](../evidence/flutter/qa286-flutter-dm-history-overlap-revision-2026-10-05-001.json).

Audio settings R10–R11 follow-up (FV2-027): source comparison found a visual
and ordering gap despite preserved audio behavior. Flutter now leads with a
device/local-check card, followed by activation, applicable shortcut, and
processing cards, with a segmented VAD/PTT selector. Widget tests cover
responsive card order/geometry and existing state; all 570 Flutter tests pass.
Android API 35 visual acceptance passes at 1080×2400 on release `1.0.30+2065`;
the compact subtitle is fully visible as a full-width body intro above the
first card, and the activation/processing cards remain readable when scrolled.
The native arm64 macOS Debug app received a DevTools hot reload in 559.8 ms; its
current screenshot/accessibility tree confirm the full subtitle and device-first
card hierarchy. The app was not restarted. Tracked in `backlog/FRONTEND_TODO.md`;
no web files were changed. See
[QA-277](../evidence/flutter/qa277-flutter-audio-settings-design-v2-2026-10-05-001.json).

Audio-preference session-restore follow-up: an existing Android API 35 install
reproduced “Сначала войдите в аккаунт” when changing the VAD threshold. The
current source already includes lazy account-scoped preference loading and
publishes the restored account before preparation (`82d572f9`, `8fe7d23d`). A
new signed arm64 Release APK `1.0.35+2068` updated in place with the same
signer and retained app data/session; changing `−50 → −48 → −50 dBFS` then
completed without an error. The same threshold change/restore was checked in
the already-running macOS Debug app. Focused test, changed-file analyzer, full
Flutter suite, and Android Release build passed. No voice call or microphone
capture was started. Tag `android-v1.0.35` will trigger the GitHub Release
workflow — [QA-298](../evidence/flutter/qa298-flutter-vad-sensitivity-session-restore-2026-10-05-001.json).

Admin panel geometry follow-up (FV2-025): web's `.admin-panel` is capped at
880 px and centered, with a visually hidden inner heading because the workspace
header already names the page. Flutter now matches that width and avoids a
duplicate visible title; the visible header remains the focused semantic
heading. Android and macOS checks pass, while Windows native acceptance remains
in FV2-006 — [QA-274](../evidence/flutter/qa274-flutter-design-v2-admin-panel-width-heading-2026-10-05-001.json).

Native video renderer source replacements are generation-scoped: a delayed
method-channel completion for `srcObject = null` can no longer clear the size
and visibility state of a newly attached stream; pending completions are
invalidated on dispose. The regression fails without this guard, all 22
WebRTC package tests and 413 Flutter client tests pass, analyzer is clean, and
the macOS Debug app builds — [QA-214](../evidence/flutter/qa214-native-video-renderer-source-generation-2026-10-02-001.json).
This source-level result does not yet prove live browser-to-Mac frames or normal
unpublish after switching; keep FE-61 open until those are observed.

Reply previews now navigate consistently in web and Flutter: targets in the
loaded window scroll into view, while targets outside it open bounded
`at`-anchored context for TEXT and DM with a return path. Focused unloaded-target
widget tests plus web navigation tests, the full Flutter suite (336), frontend
suite (713), and macOS/Android Debug builds pass. Live browser viewport,
backend/read-cursor, Windows and device acceptance remain open —
[QA-181](../evidence/flutter/qa181-reply-context-unloaded-history-2026-10-01-001.json),
[QA-182](../evidence/flutter/qa182-web-reply-context-navigation-2026-10-01-001.json).

The Flutter screen-share setup modal explicitly traps keyboard traversal; a
widget test verifies both Tab and Shift+Tab remain within the dialog. The other
settings/dialog focus paths and platform screen-reader acceptance remain open —
[QA-183](../evidence/flutter/qa183-screen-share-dialog-keyboard-loop-2026-10-01-001.json).
The Android screen-share quality picker no longer repeats an app-specific
permission warning before the system MediaProjection consent dialog. Before a
new share it now explains that Android can hide a selected app when it is fully
covered or the user switches away; the iOS app-only notice remains. Update-
quality mode omits setup guidance. All 13 picker tests and the 406-test Flutter
suite pass; Android APK and macOS debug builds pass. Analyzer reports two
existing info diagnostics in vendored `flutter_webrtc` files — [QA-203](../evidence/flutter/qa203-android-app-only-capture-guidance-2026-10-02-001.json).

Flutter destructive confirmation dialogs for message deletion, voice kick and
admin topology actions now match the web's native confirmation behavior: an
outside tap cannot accidentally discard the pending action, keyboard traversal
is kept inside the modal, Escape/Back cancels, and closing restores focus to the
opener. A widget regression covers the barrier policy, Escape and focus return;
physical keyboard/screen-reader acceptance on macOS, Windows and Android remains
open — [QA-185](../evidence/flutter/qa185-confirmation-dialog-web-parity-2026-10-01-001.json).

Flutter audio device-change handling now matches the web's missing-device
response: transient empty scans preserve the selected IDs; when a replacement
appears the first available route is selected and an accessible warning is
announced. State/UI regressions, the full Flutter suite and analyzer pass; real
hotplug and audible route switching remain unverified —
[QA-150](../evidence/flutter/qa150-audio-device-disconnect-feedback-2026-09-30-001.json).

On 2026-09-30 a signed Android 1.0.15+20 arm64 build was installed on Pixel 7
without clearing app data. The Android frame capturer's direct-ByteBuffer
`.array()` failure is fixed and covered by a native regression. A 2026-10-01
instrumented run reported `send=published`; source inspection then found the
compact Android participant strip always rendered avatars and did not consume
the thumbnail map. The strip now displays the published local preview, verified
on Pixel after rebuilding/installing the signed APK without clearing data.
Cross-client acceptance remains open: the previous Mac card still showed only
an avatar, and a rebuilt Mac Debug client stayed on “Подключаемся к гильдии…”
before receiver diagnostics could run. The earlier macOS packaging evidence
records 1.0.13+18 and predates this Android version bump —
[QA-159](../evidence/flutter/qa159-android-screen-thumbnail-buffer-2026-09-30-001.json).
The diagnostic/build changes pass all 311 Flutter tests and analyzer; the earlier
fix commit also passed GitVerse Flutter Windows CI run #1692456, including the
Windows Release build.
Two macOS crash reports captured on 2026-09-30 show the same `EXC_BAD_ACCESS`
in the queued first-frame callback of `FlutterRTCVideoRenderer`: it dereferenced
an already-cleared weak renderer after disposal. A nil guard now protects that
callback; the focused regression, all 17 plugin tests and macOS Debug build pass.
The post-fix Pixel 7 full-screen stream rendered its complete portrait frame on
Mac; the receiver stayed responsive through start, first frame and app-level
stop, with both microphones muted —
[QA-162](../evidence/flutter/qa162-macos-webrtc-renderer-dispose-race-2026-09-30-001.json).
Android local screen-thumbnail capture now bounds the native first-frame wait to
five seconds. If no frame arrives, the WebRTC sink is removed and a timeout is
returned so the serialized Flutter thumbnail queue can retry; an atomic gate
prevents a late frame from completing the same request a second time. Android
unit tests, the Dart thumbnail pipeline/widget tests and analyzer pass; at that
point the Pixel app-only preview still needed runtime acceptance —
[QA-186](../evidence/flutter/qa186-android-local-preview-frame-timeout-2026-10-01-001.json).
That app-only capture was then exercised on the connected Pixel 7 (Android 17):
Android confirmed the selected Calculator task as the projection target, and the
Flutter local thumbnail pipeline returned `captured`; the mic stayed off and
both projection and voice session were stopped afterward. The reported failure
did not reproduce on installed version 1.0.18+2023. Pixel-level visual
comparison and paired macOS/web receiver acceptance remain open —
[QA-189](../evidence/flutter/qa189-pixel7-android-app-only-local-preview-2026-10-01-001.json).
The password-reset-link and server-address dialogs on Flutter authentication
now remain open on scrim taps, keep keyboard traversal modal, close on Escape and
restore focus to their opener. Their text controllers are owned by the dialog
routes and disposed only when the reverse transition removes the fields, avoiding
the earlier use-after-dispose assertion. Auth widget tests and analyzer pass;
physical screen-reader acceptance remains open —
[QA-187](../evidence/flutter/qa187-auth-dialog-keyboard-lifecycle-2026-10-01-001.json).
The login/registration mode tabs are also verified as keyboard-operable: Tab
reaches Registration, Space activates it, and its selected state is exposed in
semantics. The auth suite (13 tests) and analyzer pass; physical keyboard and
screen-reader acceptance remains open —
[QA-188](../evidence/flutter/qa188-auth-mode-tab-keyboard-2026-10-01-001.json).
The macOS Debug 1.0.15+20 rebuild eventually restored the existing session and
reached SHARE_TEST prejoin after more than six minutes on its loading screen;
on 2026-10-01 a live process sample reproduced the wait in
`flutter_secure_storage.read` → `SecItemCopyMatching` →
`CSSM_DecryptDataFinal`, and `securityd` logged an access prompt for the v3
session-cookie service. The current ad-hoc build's CDHash is not among the hashes
listed by that Keychain ACL, consistent with authorization being requested again
after rebuild. This identifies the startup delay but does not resolve it. No
Keychain entry was modified and no password was collected. Reliable startup needs
user-approved Keychain access and stable-signature acceptance; this host has no
valid Developer ID identity —
[QA-141](../evidence/flutter/qa141-macos-keychain-access-prompt-2026-09-30-001.json),
[QA-143](../evidence/flutter/qa143-macos-keychain-v3-startup-recovery-2026-09-30-001.json),
[QA-160](../evidence/flutter/qa160-macos-debug-restart-2026-09-30-001.json),
[QA-163](../evidence/flutter/qa163-macos-keychain-prompt-runtime-2026-10-01-001.json).
The public `/maintenance` request now uses Origin/Accept-only headers so it does
not read the session cookie before `/auth/session` or on its five-second timer;
the regression and full Flutter suite pass. This removes redundant Keychain
access but does not resolve the protected session-cookie prompt —
[QA-163](../evidence/flutter/qa163-macos-keychain-prompt-runtime-2026-10-01-001.json).
An unresponsive startup session check now exits the indefinite loading state
after 20 seconds, displays the sanitized retryable error and keeps the login
session intact. On macOS the guidance calls out the system Keychain prompt. This
does not cancel the underlying native call or prove persistent startup after a
rebuild; those checks remain open — [QA-163](../evidence/flutter/qa163-macos-keychain-prompt-runtime-2026-10-01-001.json).

Flutter now submits bounded sender samples on Android/macOS/Windows and reports
the selected remote receiver every five seconds to the same authenticated
`/voice/screen-metrics` endpoint as web. Local preview is excluded, receiver
reports pause while the app is backgrounded, and both directions use only the
server's anonymous fixed-field schema. The complete Flutter test suite and
analyzer pass. The macOS Debug app, Android Debug APK and GitVerse Windows
Release workflow also compile successfully. Flutter parses native inbound `framesRendered` separately from
`framesDecoded`, derives the interval rendered FPS and sends it as
`presented_fps`; unavailable counters are omitted rather than substituted with
decoded FPS. The [W3C WebRTC Stats definition](https://www.w3.org/TR/webrtc-stats/)
increments `framesRendered` just after a frame is rendered. Remaining
acceptance: confirm native counter availability, delivery on real peers and admin snapshots — see
[QA-157](../evidence/flutter/qa157-stream-statistics-reporting-audit-2026-09-30-001.json).

The local microphone check in both clients now ends its active state and reports
the existing unavailable-device message when the selected input track or level
stream ends unexpectedly. Web track-ended and Flutter stream-completion
regressions, the full Flutter suite, analyzer and frontend production build pass;
physical disconnect/reconnect acceptance remains open —
[QA-152](../evidence/flutter/qa152-local-microphone-ended-state-parity-2026-09-30-001.json).

The authenticated prejoin roster SSE now subscribes before its initial
server-authorized snapshot is loaded. A regression test reproduces the previous
lost-wakeup window and verifies the queued event causes an immediate refresh;
package race detection and the full backend suite pass. Deployed webhook
delivery, two-account ACL isolation and reconnect behavior remain open —
[QA-137](../evidence/flutter/qa137-realtime-roster-initial-snapshot-race-2026-09-30-001.json).

The canonical OpenAPI now includes that same long-lived authenticated SSE
route and requires the server-observed `microphone_muted` participant field;
web and Flutter reject incomplete roster records rather than fabricate a muted
state. Contract assertions and full client suites pass —
[QA-138](../evidence/flutter/qa138-voice-roster-contract-sync-2026-09-30-001.json).
That revision also rebuilt the macOS Release app and the signed ABI-split Android
release APKs, while GitVerse Windows CI #1688178 passed tests, analysis and the
Windows Release build. These compile gates do not replace installed-app or
physical media acceptance; those remain open in the platform checklist —
[QA-138](../evidence/flutter/qa138-voice-roster-contract-sync-2026-09-30-001.json).

Search scope now matches the web default: opening search from an active TEXT or DM
conversation selects that conversation, while opening it from VOICE uses all
conversations. This is covered for all three contexts —
[QA-115](../evidence/flutter/qa115-search-scope-web-parity-2026-09-29-001.json).

Android voice RTT was still blank in a physical Pixel 7 check because the
listener/muted path can expose its selected ICE pair on the subscriber peer
connection, not only the publisher. Flutter now samples both peer connections,
prefers audio `remote-inbound-rtp` RTT when available, and retains the last
measurement through an empty stats sample. Pixel 7 showed 92–103 ms in both the
room badge and persistent dock with the microphone disabled —
[QA-123](../evidence/flutter/qa123-android-voice-rtt-peer-connections-2026-09-29-001.json).
Second-peer/deafen behavior and macOS, Windows and browser measurements remain
open.

Flutter search submission follows web `canSubmit`: the action and Enter handler
remain inactive for an empty query. Search keeps a polite visible status while
results are displayed or a subsequent page is loading, announcing the count and
empty state — [QA-116](../evidence/flutter/qa116-search-live-status-web-parity-2026-09-29-001.json),
[QA-117](../evidence/flutter/qa117-search-submit-web-parity-2026-09-29-001.json).

On Android 8+, `@mipmap/ic_launcher` now resolves to an adaptive icon built
from the supplied BOOHTACORD art with a transparent foreground; density PNGs
remain as the pre-API 26 fallback. The verified release APK renders on Pixel 7
in the default circular launcher style without an extra white inner frame. A
simple monochrome `B` mark is now included for Android themed icons without
changing the default full-color artwork. Themed rendering still needs physical
Pixel acceptance with the launcher theme enabled; macOS and Windows installed-
icon acceptance is also open — [QA-77](../evidence/flutter/qa77-android-adaptive-launcher-icon-2026-09-28-001.json),
[QA-133](../evidence/flutter/qa133-android-themed-launcher-icon-2026-09-29-001.json).

Mobile swipe behavior is enabled on both Android and iOS: edge navigation/member
drawers, swipe-to-reply and pull-to-refresh in text/DM history, the compact voice
dock expand/collapse, and downward exit from fullscreen viewing. Android/iOS
widget coverage now exercises the platform-gated cases; Android grants only the
active drawer edge a narrow system-gesture exclusion area (capped to a centered
200 dp vertically). Pixel 7 checks confirm both drawer edges open at the display
boundary and system Back remains available outside that region [QA-125](../evidence/flutter/qa125-android-edge-swipe-navigation-2026-09-29-001.json).
Physical iOS gesture validation remains open; shared widget coverage is recorded
in [QA-78](../evidence/flutter/qa78-android-ios-mobile-swipes-2026-09-28-001.json).

The compact mobile navigation drawer now has Android/iOS widget coverage for a
mixed `General` category containing text and voice channels, direct voice entry,
returning to text, and opening DMs. The Android 320 dp empty-drawer case remains
covered as well —
[QA-79](../evidence/flutter/qa79-android-unified-channel-drawer-2026-09-28-001.json).

At 320 dp, an Android test exposed and now prevents a bottom overflow in the
empty text-channel welcome state when the channel name wraps across several
lines. The empty state retains its minimum visual height but can grow and scroll
with its content —
[QA-80](../evidence/flutter/qa80-android-empty-channel-320dp-2026-09-28-001.json).

The Android-to-browser crop is now reproduced and has a concrete web-layout fix:
the video already used `object-fit: contain`, but as a grid item it retained an
automatic intrinsic minimum size and the stage's `overflow: hidden` clipped its
lower portion. The player now has `min-width: 0; min-height: 0`; its regression
test failed before the fix and passes after it, and the frontend production build
passes [QA-132](../evidence/flutter/qa132-browser-android-screen-share-crop-2026-09-29-001.json).
The 2026-09-30 production stylesheet check confirms the deployed `.screen-player`
contains `min-width: 0; min-height: 0`. CSS delivery is verified; confirm the
full frame with a new Pixel share. Flutter's LiveKit renderer uses
`VideoViewFit.contain`; neither that nor receiver dimensions prove that all four
source edges arrive. The Android encoder wrapper also now adapts on a mismatch
in either source axis [QA-93](../evidence/flutter/qa93-android-encoder-height-resize-2026-09-29-001.json).
Keep the full crop gate open until portrait and landscape shares are checked in
both deployed web and Flutter viewers.

## Delivery sequence

### 0. Baseline and acceptance map — in progress

- Map every web route/panel, visible control, state transition, API call and ACL
  rule to Flutter.
- Keep the parity table above current and link each gap to its source components
  and contract operation.
- Capture web reference screenshots for signed-out, text chat, DM, member
  drawer, voice prejoin, active voice, screen viewer, profile, audio and admin.
- Record common viewport sizes: 1440×900, 1280×800, 1024×768 and Android
  portrait. Use the same account/data in both clients.

### 1. Design foundation and workspace shell — in progress

- QA-97 records parity with the earlier web token set, before Design V2 changed
  `clients/web/src/design/tokens.css`. The 2026-10-03 Flutter V2 leaf now aligns
  the semantic palette, avatar/voice/stream colors, radii, layout dimensions,
  overlay and focus colors to the current CSS contract; tests assert the exact
  values and Android/macOS Debug builds pass —
  [QA-237](../evidence/flutter/qa237-flutter-design-v2-theme-tokens-2026-10-03-001.json).
  Auth tabs retain their web-specific 40 px height and padded Material hit
  targets remain available. The earlier QA-97 record remains historical evidence.
- FV2-007 now matches the web Design V2 responsive geometry for the tested text
  and DM states: edge-to-edge shell, 280/248 px desktop columns, 56/64 px
  conversation headers, 36 px desktop and 44 px compact-drawer channel rows,
  chat list padding/rhythm/avatar sizes, and 70/98 px composer bands. Widget
  assertions cover 320/360/390/1024/1280/1440 px; all 462 Flutter tests,
  changed-file analysis, Android Debug APK and macOS Debug builds pass —
  [QA-238](../evidence/flutter/qa238-flutter-design-v2-shell-chat-geometry-2026-10-03-001.json).
  Screenshot comparison, Windows build, and runtime acceptance are not run.
- FV2-008 aligns the TEXT/DM reply state with the web geometry: a 41 px bordered
  reply target joins the lower-rounded 52/54 px composer inside a 131 px band;
  both use the shared 24 px horizontal/18 px bottom reply padding and web
  surface colors. DM now uses the same one-line composer hint as web. Tests cover
  390 px and 1440 px for both conversation types, including cancel; the full
  suite (463), WorkspaceScreen tests (61), changed-file analysis and Android /
  macOS Debug builds pass —
  [QA-239](../evidence/flutter/qa239-flutter-design-v2-reply-composer-2026-10-03-001.json).
  Screenshot comparison, Windows build and device runtime are not run.
- FV2-009 aligns the screen-selection rail with the production web Design V2
  card geometry: desktop rail/cards/previews are 100 / 152×96 / 142×60 px;
  compact sizes at 390 px are 84 / 128×80 / 118×48 px. Remote thumbnail uses
  cover scaling, the selected card shows «ЭФИР», and local/remote selection
  semantics remain available. Focused geometry/thumbnail tests, the full suite
  (464), changed-file analysis, Android Debug APK and macOS Debug builds pass —
  [QA-240](../evidence/flutter/qa240-flutter-design-v2-screen-rail-2026-10-03-001.json).
  Screenshot comparison, Windows build and runtime acceptance remain NOT_RUN;
  no LiveKit lifecycle or publishing behavior changed.
- Remaining FV2-002 work includes full message/history and attachment
  visual states plus on-device scroll/read-cursor/IME acceptance. Match remaining
  shell interactions at wide, medium and compact widths.
- Implement web-equivalent responsive navigation/member/search drawers,
  scrim, escape/close behavior, focus return and keyboard reachability. Navigation
  and member drawers preserve the active channel/voice view behind a scrim;
  compact and medium widths use overlays while wide layouts retain the member
  aside. Drawer overlays now own a closed-loop focus scope, exclude the covered
  workspace from keyboard traversal and restore the opening focus on close.
  Search remains beside the conversation on wide layouts and uses a trapped,
  scrim-backed right panel below 1280 px and over wide voice stages. Search
  Ctrl/Cmd+K launch, Escape close, focus return and live loading/error/empty
  announcements are implemented. Exact breakpoints, other panel focus and
  screenshot comparison remain open.
- Match header, channel navigation, selected/hover/focus states, user footer,
  member aside and voice dock sizes and copy.

### 2. Identity and account settings

- Maintenance status now uses a public SSE stream and displays the shared
  banner above both guest and workspace screens. Flutter reconnects after a
  dropped stream and retains the last known state during transient failures.
- Protected REST 401s now clear the local cookie and private workspace; an
  invalid login response is excluded from this path. On realtime disconnect,
  Flutter verifies `/auth/session` before retrying, so network outages retry
  without signing out while expired sessions return to the guest screen.
- Native clients now accept a pasted reset URL, validate HTTPS/same-origin/path,
  extract the 43-character fragment token only into memory, clear the entry
  field, and submit it in the request body. Terminal results return to login
  with focus; automatic OS opening of the HTTPS URL remains open until domain
  association is configured for actual platform signing identities.
- Match login/register validation, server configuration and remaining
  web-equivalent focus/error states.
- Profile avatar upload/delete now use the caller-only `/me/avatar` contract,
  native file selection, PNG/JPEG signature validation and the 2 MiB cap. Name
  and password updates already have client validation and saved/error feedback.
- Logout section/flow now stops voice, only clears local authenticated state
  after server-confirmed revocation, and preserves the cookie for retry on
  failure. Still match profile loading/error/focus states.
- Web notifications are local browser-only preferences backed by Notification
  permission, local storage and Web Locks deduplication; there is no server
  notification contract. Flutter now has platform-aware local notification
  preferences and generic previews without message content [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json);
  OS permission/delivery acceptance on physical macOS, Windows and Android
  remains open.
- Automatic OS delivery of the reset URL remains open. The native paste flow
  does not persist or log the token and sends it only in the request body.

### 3. Channel navigation and administration

- Text channel unread and mention counts now parse from the authenticated
  topology response and render only for TEXT channels. Empty categories match
  the web copy. Opening a channel scrolls to latest and advances the caller's
  monotonic read cursor to the newest rendered message intersecting the
  conversation viewport only while the app is foregrounded; scrolling older
  cannot regress it, and successful advancement reloads server counts.
- Connected voice navigation now mirrors live member count and roster status
  (mic, speaking and screen sharing) from LiveKit events. Non-connected
  navigation receives authenticated roster snapshots through a long-lived SSE
  stream with periodic session revalidation; signed LiveKit webhook events only invalidate snapshots, and each
  snapshot rechecks channel visibility and active leases. Both web and Flutter
  now avoid thumbnail DataPackets; the production credential intentionally
  keeps `CanPublishData=false`. Web uses `autoSubscribe=false`, briefly
  serializes preview subscriptions so at most one active screen-video track is
  sampled per room; it captures a bounded JPEG (up to 12 attempts at 250 ms,
  max 14 KiB), then unsubscribes after the first usable frame. A selected
  full-screen viewer retains its subscription, and an existing thumbnail
  remains visible after preview unsubscribe until the share is unpublished.
  Flutter now connects with `autoSubscribe=false`, explicitly subscribes to
  microphone tracks, and serializes temporary screen-video preview
  subscriptions: at most one hidden screen is sampled at a time, a bounded
  JPEG is captured after decoded frames arrive, then the track is unsubscribed.
  A selected viewer explicitly retains its video/audio subscriptions, and an
  existing thumbnail remains visible after preview unsubscribe until the share
  is unpublished. Reconnects restore microphone, preview, and selected-viewer
  subscriptions. Keep the broad data grant disabled. ADR-013 records the
  room-scoped track-preview constraints. Earlier roster and packet evidence is
  in [QA-134](../evidence/flutter/qa134-realtime-voice-roster-screen-thumbnails-2026-09-30-001.json)
  and [QA-159](../evidence/flutter/qa159-android-screen-thumbnail-buffer-2026-09-30-001.json).
  Web's 709 tests and production build pass for the new receiver path, but the
  paired live thumbnail test has not yet run —
  [QA-165](../evidence/flutter/qa165-web-screen-thumbnail-receiver-capture-2026-10-01-001.json).
  The web adapter now also has a regression test for selecting a screen while
  its thumbnail capture is still in flight: completion retains the selected
  viewer subscription. All 710 frontend tests and the production typecheck/build
  pass — [QA-168](../evidence/flutter/qa168-web-preview-selection-during-capture-2026-10-01-001.json).
  Flutter's 322-test/analyzer run, Android ABI-split release build, and
  macOS Debug build pass; runtime preview acceptance on Android/macOS/Windows
  remains open because the Pixel is disconnected and no fresh paired
  screen-share test has run —
  [QA-166](../evidence/flutter/qa166-flutter-temporary-screen-subscriptions-2026-10-01-001.json).
  Follow-up regression coverage now also verifies that temporary subscriptions
  always clean up on capture failure and that a viewer selection made during
  capture retains playback; stale async viewer selections no longer subscribe
  after a newer selection. All 326 tests, analyzer, Android 1.0.17+22
  ABI-split Release and current-source macOS Debug builds pass —
  [QA-167](../evidence/flutter/qa167-flutter-preview-subscription-race-2026-10-01-001.json).
  Close cross-client preview only after Flutter's temporary subscription policy
  and the paired live test satisfy [ADR-013](adr/ADR-013-room-scoped-screen-thumbnail-preview.md).
- Port admin topology operations with confirmations, revision conflicts and
  refresh recovery. Initial slice now adds authenticated category/channel
  create/rename and empty-category deletion, admin-only entry, server-side
  authorization, confirmation before category deletion, and refresh after
  stale-topology conflicts. Category/channel ordering and channel movement now
  send the current topology revision and refresh after mutation/conflict. TEXT
  archive and VOICE admission close now use the expected-revision contracts and
  web-equivalent confirmations. Voice close copy explicitly says SFU media
  revocation is pending; a revoked-lease count is not described as a confirmed
  disconnect. The audit tab now uses the opaque `before` cursor and matches the
  web event-title/actor/target presentation without message content. The
  section navigation now exposes a named tablist and selected tab semantics
  to match the web nav's current-page state [QA-101](../evidence/flutter/qa101-admin-section-tab-semantics-2026-09-29-001.json). Admin
  Members and Audit initial loading states now use the web's visible status
  copy and polite live-region announcement instead of an unlabeled spinner;
  widget tests verify the spoken loading semantics and the subsequent empty
  state, and Windows CI passes [QA-102](../evidence/flutter/qa102-admin-loading-live-regions-2026-09-29-001.json).
  Native VoiceOver/TalkBack acceptance remains open.
  members now use the 100-item account cursor, per-row role/block drafts,
  save, focus restoration, one-time reset-link display/copy/close and same-voice
  kick contract. Widget coverage exercises account pagination, retained drafts
  on save failure, focus after success/failure, reset-link expiry/copy/close and
  audit empty/error/refresh states. The Media tab now uses the web's anonymous,
  fixed-enum `/admin/screen-metrics` response, validates its bounded samples,
  shows the same platform/direction/state and frame/FPS/network fields, and
  polls every five seconds only while selected and foregrounded. Widget tests
  cover empty/populated/error/retry states, narrow width, polling and polling
  shutdown on tab switch. Live REST ACL verification and matched screenshot
  comparison across all four tabs remain open [QA-100](../evidence/flutter/qa100-admin-media-diagnostics-2026-09-29-001.json).

### 4. Text conversations

- Same-author grouping, local-date separators and message-body formatting now
  follow the web rules. Flutter supports paragraphs, bold, italic, inline code,
  fenced code and clickable HTTP(S) links; unsafe link schemes stay plain text.
  Mention IDs are parsed and resolved to member names in TEXT and DM history.
  Same-author grouping uses:
  same author, no reply/deleted boundary, same local date, and a gap of at most
  five minutes. History remains chronological and visible-message read tracking
  still keys only message rows. Older history now loads from the server cursor,
  deduplicates rows and restores the viewport offset after prepending. Reply
  actions now set/cancel a scoped composer
  target, send `reply_to_id`, render a preview, and jump to the referenced row
  when it is loaded. DM reply preview uses the server's `reply_preview` contract
  (or local history as fallback). History-to-specific-message context jumps,
  author directory coverage and screenshot comparison remain.
- Mention picker now submits selected IDs with the message; DM choices are
  limited to the conversation participant. Native notification behavior needs
  a separate platform-aware design. Optimistic rows and explicit send retries
  are implemented; edit revision conflicts now keep the draft, refresh only
  the target revision and allow another explicit save without dropping loaded
  history. Delete updates the loaded row locally. Live backend checks remain.
- Attachment picker/upload, 10-file/25 MB limits, send binding, private image
  preview and native save flow now work on desktop and Android. Multipart bytes
  report per-file progress; failed files can be retried without discarding
  successful IDs, and conversation switching cannot redirect selected bytes.
  Native clipboard PNG paste is now wired through the same queue with
  `Ctrl/Cmd+V`, `Shift+Insert`, a context-menu action and a visible paste
  control. Co-pasted plain text is inserted at the current selection; clipboard
  reads happen only after an explicit paste action. Widget tests cover the
  TEXT/DM scope, limits and retry; real clipboard/permission acceptance remains.
  Images open in an authenticated, viewport-filling viewer with web-matching
  filename/header, separate download action, fit-to-window image stage, loading,
  transient retry and deleted/unavailable states. The old Flutter constrained
  dialog and pinch/scroll zoom are removed to match the web viewer. Test-first
  responsive/error coverage, viewer-focused suite (12/12), and full combined
  suite (525/525) pass. The upstream microphone-controls merge initially exposed
  unresolved method-channel timeout timers under FakeAsync; a test-only default
  channel fixture and robust audio-panel scrolling resolved it — [QA-265](../evidence/flutter/qa265-flutter-native-audio-test-harness-2026-10-05-001.json).
  Targeted analysis, macOS Debug build and signed Android ABI-split Release
  builds pass — [QA-264](../evidence/flutter/qa264-flutter-protected-image-viewer-overlay-2026-10-05-001.json).
  Live visual acceptance remains open: the already-running Mac app has no
  attachable Flutter VM service and is intentionally not restarted; the Android
  emulator has installed versionCode 2053 while the canonical arm64 split build
  is versionCode 2043, so no downgrade/install was attempted. Windows runtime
  acceptance also remains open. Saving remains a separate authenticated action.
  Verify the existing 24-hour server-side unattached cleanup, live 507 handling,
  attachment ACL and visual comparison on devices.
- Channel/DM search, result context and return-to-origin are implemented with
  cursor pagination and an `at=<messageId>` history request. The search panel
  now keeps the conversation visible, follows responsive modal/aside behavior,
  traps focus only when modal, and announces loading/error/empty states. Compare
  its screenshots and screen-reader output on devices. Ctrl/Cmd+K is ignored
  while an editable text field owns focus; Escape closes the search panel and
  restores focus to the launcher (reopening compact navigation when necessary).

### 5. Direct messages and unified search

- Match candidate discovery, navigation badges, read cursor and realtime
  delivery. Cursor pagination and scroll restoration are now implemented.
- Reply compose/preview, participant-only mention picker, attachment upload,
  private preview/save and scoped native clipboard paste, plus edit/delete are
  implemented with participant ACLs; add device acceptance for private upload,
  retry/progress and send/conflict recovery.
- Global search and conversation-scoped context navigation are implemented;
  Ctrl/Cmd+K, Escape and launcher focus restoration are implemented and covered
  by widget tests; responsive modal search traps focus below 1280 px, while the
  wide side panel leaves the conversation and navigation available. Visual and
  screen-reader comparison remain.

### 6. Members and voice lifecycle

- Match member presence groups, anchored profile popover and DM entry.
- Voice participant cards now expose a 0–200% microphone control. The level is
  stored by signed-in account and remote account, preserves any saved screen
  level, and is reapplied when a track subscribes or the room reconnects.
  Verify actual gain with two real peers on macOS, Windows and Android.
  The member profile dialog also exposes
  this level for members in the same voice room. Its anchored popover now uses
  the web's responsive aside width, 16 px right inset, row-top alignment, avatar,
  identity typography and 40 px full-width actions; the volume percentage is
  separated from its label as in the web grid
  [QA-34](../evidence/flutter/qa34-member-profile-popover-web-geometry-2026-09-28-001.json).
- Listener-only join now follows the web prejoin action and connects without
  enabling the microphone; regular join retains its mic-permission fallback.
  When microphone capture fails, Flutter now explicitly marks the local
  participant as unavailable, explains that the room was joined as a listener,
  and offers a retry. Push-to-talk mode instead asks for the assigned key to be
  held, so retry never opens the microphone outside the user's PTT gesture
  [QA-32](../evidence/flutter/qa32-voice-microphone-unavailable-fallback-2026-09-27-001.json).
  Web keeps transfer as a separate action. In mobile Flutter navigation, tapping
  a voice channel starts admission and retries once with transfer after
  `ACTIVE_VOICE_LEASE` ([ADR-012](adr/ADR-012-mobile-voice-direct-entry.md)). LiveKit reconnect/resume events now
  surface a reconnecting state, preserve the current mic state and temporarily
  disable mic/deafen controls. Terminal disconnects clear local state and
  release the lease. The Flutter client now ends active-room recovery after
  the same six retries as web, uses the same 250/500/1000/2000/4000/4000 ms
  exponential bases with ±20% jitter, and gives explicit retry-limit guidance
  [QA-33](../evidence/flutter/qa33-flutter-voice-reconnect-limit-2026-09-28-001.json),
  [QA-86](../evidence/flutter/qa86-voice-reconnect-web-parity-2026-09-29-001.json).
  Participant status labels and speaking indicators now share the web priority:
  deafen, unavailable microphone, muted, speaking, then in-channel. All active
  voice representations suppress speaking when the microphone is unavailable,
  muted or deafened [QA-35](../evidence/flutter/qa35-voice-participant-status-web-parity-2026-09-28-001.json).
  Realtime lease revocation now validates both the active
  lease ID and the known reason, including revocation arriving during join, and
  displays the web-equivalent reason. Verify reconnect runtime behavior on real
  peers; permission-denied and
  remaining dock/device states also need platform acceptance.
- Match dock/prejoin/active/reconnecting/error states and their accessible labels.
  Voice prejoin now uses the web's viewport-clamped page inset and card padding,
  compact 16×24 px padding and bordered raised icon. A 390 px mobile test caught
  a two-line channel header overflowing its 72 px slot; title/subtitle now ellipsize
  [QA-62](../evidence/flutter/qa62-voice-prejoin-responsive-web-parity-2026-09-28-001.json).
  Voice dock mic, deafen and stream-alert controls now expose web-equivalent
  action labels and pressed/toggled semantics [QA-58](../evidence/flutter/qa58-voice-dock-accessible-toggle-state-2026-09-28-001.json);
  compact Android now keeps these controls in a reserved bottom dock rather
  than requiring the navigation drawer; its widget test verifies the dock and
  actions at 390×844 and 320×640 and while the drawer is open
  [QA-66](../evidence/flutter/qa66-android-mobile-voice-dock-2026-09-28-001.json).
  Verify their announcements with VoiceOver, NVDA and TalkBack on native devices.

### 7. Audio and screen sharing

- Native audio settings are now reachable from account settings and expose
  input/output device selection plus account-scoped saved device IDs and
  processing toggles (AGC, echo cancellation, noise suppression). Selection
  routes through LiveKit/native audio APIs; active local tracks receive device
  and runtime processing changes. The UI explicitly says the native SDK does
  not report effective processing state, rather than claiming the requested
  value was applied. Verify device switching and processing audibly on
  macOS/Windows/Android. VAD/PTT mode and account-scoped key assignment are
  implemented. Desktop PTT mutes on join and key release and is force-released
  on app backgrounding, desktop window blur, or voice teardown; text-entry,
  dialog and capture focus do not accidentally transmit. Android/iOS PTT does
  not require a hardware key: hold the microphone button in the compact voice
  dock to talk; pointer release/cancel and dock teardown mute it. Widget/unit
  coverage verifies pointer up and pointer cancel and passes
  [QA-213](../evidence/flutter/qa213-mobile-push-to-talk-touch-2026-10-02-001.json).
  Android Emulator API 35 runtime acceptance confirmed selecting PTT without a key,
  mic activation only while the touch was held, and automatic mute after release;
  VAD was restored after the test [QA-223](../evidence/flutter/qa223-android-emulator-touch-ptt-runtime-2026-10-02-001.json).
  Verify system interruption, backgrounding and screen-reader behavior on physical
  Android/iOS devices, and retain hardware-key focus tests on desktop.
- Local screen picker/publish/stop is implemented for connected voice rooms;
  desktop uses LiveKit's screen/window picker, while Android requests the
  native MediaProjection grant and runs its declared `mediaProjection`
  foreground service with a sharing notification. Android intentionally does
  not request battery-optimization exemptions. Local capture is shown as a
  preview and can be stopped from the voice header; stopping on the OS side is
  intended to be reflected by LiveKit's track-unpublished event. The latest
  Pixel 7 check found the app's `flutter_background` notification channel
  disabled (`importance=NONE`); after system projection ended, the black local
  preview/share UI remained until the in-app stop control was tapped. The
  pinned `flutter_webrtc` source had an empty Android `MediaProjection.Callback`
  and did not forward capture-ended to Dart; the local fork now releases the
  capturer and dispatches the ended event to LiveKit. Unit tests and release
  compilation pass, but the device regression still needs a repeat with the
  notification enabled by the user, confirming UI/metrics clear immediately
  after OS stop [QA-26](../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
  Native screen audio is not
  supported by the current capture API, so local screen shares are video-only.
  Verify OS-level stop, Android 14+ permission/service behavior, and real-peer
  capture on macOS, Windows and Android.
- Android now includes the real MediaProjection source dimensions in the
  Flutter WebRTC track settings. Flutter passes those dimensions to the selected
  quality profile, which applies an even, aspect-preserving RTP scale cap
  (720/1080/1440p) instead of treating bitrate/FPS as the only effective
  profile settings [QA-88](../evidence/flutter/qa88-android-screen-share-resolution-cap-2026-09-29-001.json).
  Sender-stat confirmation across Android profiles and receiver-edge/crop
  acceptance remain open; this encoder cap is not evidence that the reported
  receiver crop is fixed.
- macOS 13+ full-display ScreenCaptureKit now consumes the selected profile's
  resolution ceiling and frame rate, preserving the display aspect ratio in
  its output buffer [QA-89](../evidence/flutter/qa89-macos-screen-share-profile-cap-2026-09-29-001.json).
  Custom window capture and the macOS 12 screen fallback now pass frames
  through an aspect-preserving long-edge cap before the WebRTC source; frames
  already within the profile are left intact [QA-92](../evidence/flutter/qa92-macos-legacy-and-window-screen-share-profile-cap-2026-09-29-001.json).
  The macOS 12 fallback also retains the display chosen in the source picker
  instead of reverting to the primary display [QA-91](../evidence/flutter/qa91-macos-legacy-selected-screen-source-2026-09-29-001.json).
  Verify real source dimensions, edges, and all nine profiles on both legacy
  display and window capture before marking runtime acceptance complete.
- Windows source previews are native-sized JPEG frames in the pinned
  `libwebrtc.m150.7871.02` wrapper. The selected preview's JPEG SOF dimensions
  now feed LiveKit's existing aspect-preserving `scaleResolutionDownBy` profile
  cap; the setup waits for those dimensions rather than publishing uncapped.
  Keep the race regression covered, then verify actual sender stats for all nine
  profiles on both screen and window sources on a Windows runtime before
  claiming platform acceptance [QA-90](../evidence/flutter/qa90-windows-screen-share-profile-cap-2026-09-29-001.json).
- Match viewer stream rail, explicit selection, fullscreen, screen audio/volume,
  quality controls and diagnostics. The web and Flutter clients now share the
  720/1080/1440p × 15/30/60 FPS capture matrix, bitrate policy, and track labels;
  the chosen web profile is reused by both in-room and persistent-dock start
  controls. Web now presents an accessible quality setup dialog before invoking
  the browser's native source chooser; the same dialog opens from both start
  controls, and the persistent dock switches to a stop action while sharing
  [QA-83](../evidence/flutter/qa83-screen-share-profile-web-parity-2026-09-29-001.json),
  [QA-84](../evidence/flutter/qa84-web-screen-share-setup-parity-2026-09-29-001.json).
  The remote audio slider now follows the
  selected stream's account-scoped preference and distinguishes absent audio
  from deafen. The selectable stream rail now sits below the video stage rather
  than obscuring its lower edge; stream cards follow the web avatar/name/status/
  audio/selected-marker layout and expose track availability to assistive tech
  [QA-37](../evidence/flutter/qa37-voice-viewer-rail-web-parity-2026-09-28-001.json).
  If a selected remote screen disappears, Flutter now retains a distinct ended
  state and waits for an explicit selection or return-to-participants action;
  it does not silently fall back to the local share
  [QA-38](../evidence/flutter/qa38-voice-screen-ended-state-2026-09-28-001.json).
  Viewer selection state is keyed to its voice-channel ID, preventing a stream
  identity or ended-state from leaking into another room
  [QA-39](../evidence/flutter/qa39-voice-channel-viewer-scope-2026-09-28-001.json).
  Remote streams can now be pinned into a workspace mini-player that remains
  visible over another channel, a DM, or workspace panels; return-to-viewer,
  transient screen-audio mute, and stop-watching controls match the web
  conversation mini-player policy [QA-94](../evidence/flutter/qa94-pinned-screen-mini-player-web-parity-2026-09-29-001.json).
  When the selected screen publication is removed, Flutter now closes the
  pinned mini-player but preserves the ended state in the visible voice room;
  a temporarily missing frame remains a waiting state [QA-95](../evidence/flutter/qa95-pinned-screen-ended-lifecycle-2026-09-29-001.json).
  Mini-player layering also matches the web stack: above content but beneath
  scrims/drawers/search, excluded from hidden-overlay focus/semantics, and
  positioned just above the compact voice dock [QA-96](../evidence/flutter/qa96-pinned-screen-overlay-layering-2026-09-29-001.json).
  Verify actual playback/gain and matched viewer screenshots on each target
  platform. For the previously reported Android receiver crop, explicitly
  compare portrait and landscape captures in web and Flutter, confirming all
  four frame edges remain visible after attach, rotation/resize and fullscreen;
  sender/receiver dimension metrics alone do not prove aspect-fit playback.
- Keep platform-specific permission prompts native while preserving the same
  in-app flow and recovery copy.

### 8. Parity gate and release

- A fresh macOS debug launch exposed a legacy Keychain stall: the native sample
  showed `flutter_secure_storage` blocked in `SecItemCopyMatching` while
  `SecurityServer` decrypted a legacy item. macOS now uses the Data Protection
  Keychain; debug startup reaches the signed-out login screen. Verify signed
  release persistence and the one-time re-login behavior for legacy cookies
  [QA-40](../evidence/flutter/qa40-macos-startup-loading-2026-09-28-001.json).
- A later login screenshot exposed `errSecMissingEntitlement` (`-34018`) from
  the Data Protection Keychain. macOS now uses the package-supported legacy
  Keychain mode under an app-specific service name, avoiding both the sharing
  entitlement and the old default-service item that stalled on this host. The
  debug build launches without the exception; confirm successful session
  write/read across a relaunch and the one-time re-login behavior for old
  cookies [QA-60](../evidence/flutter/qa60-macos-keychain-entitlement-2026-09-28-001.json).
  A fresh launch later reproduced an indefinite Keychain read; sampling traced
  it to `SecItemCopyMatching`/`CSSM_DecryptDataFinal`. Session storage now uses
  an isolated `.session.v2` service and the debug app reaches login again.
  Existing items remain untouched; successful login persistence and relaunch
  acceptance are still open [QA-99](../evidence/flutter/qa99-macos-keychain-service-rotation-2026-09-29-001.json).
- Compare reference and Flutter screenshots at the same viewport and data;
  track geometry/color/type deviations per screen.
- Exercise every control and non-happy state against the same backend contracts.
- Check keyboard/focus, accessibility labels, narrow layouts and window resize
  behavior on macOS, Windows and Android.
- Local macOS release builds and verifies as an ad-hoc universal bundle, but
  there is no Developer ID team signature and signed-release Keychain
  persistence has not been tested [QA-85](../evidence/flutter/qa85-macos-release-bundle-2026-09-29-001.json).
  Local verification covers macOS debug/release builds and Android debug; the
  tracked Android 1.0.0+3 release APK was rebuilt from `f162973`, passes APK
  Signature Scheme v2 verification, and has a recorded upload-certificate
  fingerprint, SHA-256 and size [QA-88](../evidence/flutter/qa88-android-screen-share-resolution-cap-2026-09-29-001.json).
  Signed macOS release persistence and Android install/runtime acceptance on a
  physical device remain open.
  The GitVerse workflow in `.gitverse/workflows/flutter-windows.yaml` now routes
  to the registered `boohtacord-win-station`. Flutter 3.47.5, dependency
  resolution, tests, analysis and the Windows Release build pass; the workflow
  explicitly creates/validates plugin junctions so it does not depend on
  Developer Mode [QA-81](../evidence/flutter/qa81-gitverse-windows-runner-ci-2026-09-29-004.json).
  Launching the built client and Windows runtime/screenshot parity remain open.
- Android Debug and signed Release compile in both AGP Kotlin modes. The local
  `flutter_background` 1.3.1 fork conditionally applies KGP only when built-in
  Kotlin is disabled; CI now exercises both modes. Flutter still warns about KGP
  declarations from `flutter_background`, `flutter_webrtc` and `livekit_client`,
  so keep the current default disabled until the other local plugin forks and
  Flutter's compatibility detection are addressed — [QA-172](../evidence/flutter/qa172-android-kotlin-build-modes-2026-10-01-001.json).
- Do not mark a row complete until both the feature and its visual/state parity
  criteria have evidence.

## First implementation slices

The shell pass ports the design tokens and aligns geometry with
`clients/web/src/design/shell.css` and `responsive_shell.css`: wide navigation and
member columns, medium widths, frame inset, border and shell radius. Responsive
drawers and search panel are implemented, including scrim, modal focus trapping
and restoration; exact breakpoints, typography and per-screen screenshot
comparison remain open in phase 1.
The identity slice adds caller-only avatar upload/delete, logout failure
semantics, maintenance status and pasted one-use password-reset links. Channel
navigation now carries text-only unread/mention counts and a foreground read
cursor based on the newest visible message. Text history now groups eligible
same-author messages, inserts local-date dividers and renders web-compatible
body formatting, member-name mention picker and mention IDs in TEXT/DM history;
HTTP(S) links open through the platform. TEXT and DM attachments now support
native picking, authenticated upload, sending, protected preview and saving.
Voice prejoin retains a listener-only action, while mobile channel taps join
directly and transfer an existing lease once when needed; active rooms render participant cards/status and remote screen
viewing. Search now spans all conversations or the active channel/DM, opens
server-centered context and returns to the originating conversation in a
responsive side panel that preserves the active conversation. Screenshot and
device screen-reader comparison, real-peer voice/screen-audio gain and PTT
verification, bounded reconnect retry policy, native notification OS delivery,
attachment cleanup, admin member actions and Windows runtime verification
remain open. Local screen publishing now has clients/flutter/Android controls and
Android foreground-service plumbing, but still needs OS-level and real-peer
verification. Live voice navigation refreshes its roster from participant,
track and speaker events. Lease-specific revocation and visible reconnect
states are implemented, but still need backend-driven integration coverage and
screenshot comparison.

Conversation and voice error banners expose `SemanticsRole.alert`, matching the
web TEXT/DM `role="alert"` in Flutter's semantics tree. A TEXT widget regression
reproduced the missing alert role before the change; focused, workspace and full
Flutter suites plus analyzer pass —
[QA-155](../evidence/flutter/qa155-conversation-error-live-alert-parity-2026-09-30-001.json).
Windows/macOS engine alert events and actual spoken timing/priority remain open
for native acceptance. Android adds a separate polite live-region child because
its bridge does not map alert role to a live region; the APK compiles, but actual
TalkBack announcement and parity with web's assertive urgency remain unproven.
The GitVerse Windows CI run 1690633 passed tests, analysis and Release build on a
commit containing this change.

The latest Pixel 7 app-only tests are recorded in [QA-197](../evidence/flutter/qa197-android-preview-render-event-2026-10-01-001.json), [QA-198](../evidence/flutter/qa198-pixel7-preview-impeller-ab-2026-10-01-001.json), and [QA-199](../evidence/flutter/qa199-pixel7-preview-surfacetexture-ab-2026-10-01-001.json). On `1.0.18+2027`, `first_swap_buffers` fired and the Calculator thumbnail appeared while the large preview stayed black. The `1.0.18+2028` A/B opted out of Impeller with SurfaceProducer; `1.0.18+2029` used legacy SurfaceTextureEntry with the same opt-out. Both reproduced the black preview, while capture targeted Calculator and encoder dimensions were 1080×2400. Thus neither Impeller opt-out nor choosing one of these two texture backends explains/resolves the issue. Source review then identified a potential race between asynchronous EGL surface release and immediate Flutter SurfaceProducer resize; a release barrier has been implemented with ordering tests and release APK `1.0.18+2030` compiles [QA-200](../evidence/flutter/qa200-android-screen-preview-egl-resize-barrier-2026-10-01-001.json). The Pixel was disconnected, so app-only/full-display runtime behavior and paired receiver playback are still unverified. FE-59 remains open pending device acceptance.

On Android Emulator API 35, release-signed `1.0.23+2036` additionally verified the app-only source-hidden state end to end: Android's MediaProjection visibility callback reached the matching Flutter track, and switching from Clock back to BOOHTACORD replaced the endless first-frame spinner with an explicit message that Android hid the selected app. Stop/leave cleared MediaProjection. This improves failure feedback but does not prove pixel rendering or remote playback; physical Pixel and paired receiver acceptance remain open — [QA-225](../evidence/flutter/qa225-android-app-only-hidden-source-feedback-2026-10-02-001.json).

On 2026-10-03, a paired Android Emulator→macOS run in `SHARE_TEST` showed the selected portrait app frame end-to-end: macOS rendered all edges with letterboxing, and its receiver sample reported 576×1280 at 15 FPS, 15 decoded FPS, 151 kbit/s, 0% loss and 9 ms jitter. Returning BOOHTACORD showed Android's explicit app-hidden state; macOS retained the last decoded frame while receive/decode counters dropped to zero. Stopping cleared MediaProjection and removed the publication. Android was still on installed `1.0.25+2039` while the macOS Debug client was `1.0.28+42`; no simultaneous Android sender sample, browser receiver/source or physical Pixel was included, so current-source counter correlation remains open — [QA-234](../evidence/flutter/qa234-android-emulator-macos-live-screen-share-2026-10-03-001.json).

On 2026-10-05, the current signed Android `1.0.34+67` full-display publication was
discovered and rendered by the already-running macOS client. The full portrait
Clock Stopwatch frame was visible without cropping and its elapsed value
advanced. With the selected `720p/15 FPS` profile, the changing-frame receiver
sample reached 384×853, 6.5 decoded FPS, 124 kbit/s, 0% loss and 49 ms jitter;
these emulator measurements are below the selected rate and do not prove a
hardware performance ceiling. Screen share stop cleared MediaProjection and
removed the remote publication. Sender/receiver correlation, browser/physical
Pixel acceptance and profile-rate investigation remain open —
[QA-290](../evidence/flutter/qa290-android-current-release-macos-screen-share-runtime-2026-10-05-001.json).

During the same paired run, the Flutter main viewer showed the moving remote
Clock frame while the selected screen-rail card still showed the publisher
avatar. The temporary preview path correctly skips a participant already
selected for persistent playback, but the persistent `TrackSubscribed` path had
no thumbnail capture. It now captures a bounded thumbnail for the selected
remote video while avoiding duplicate work from a temporary preview; selecting
an already-subscribed track also starts capture to close the cancellation race.
Policy, pipeline and rail tests, all 637 Flutter tests, changed-file analysis, a
signed Android arm64 Release APK and macOS Debug build pass. The release APK was
installed in place on API 35 without clearing app data. A later paired retest
initially still showed the avatar on the already-running macOS build. DevTools
reported hot reload completed, but the Mac app returned to startup and then
`Не удалось проверить сессию`; its in-place retry timed out the same way, with
no Keychain prompt. The Android test projection was stopped and verified
cleared (`MediaProjection=null`). The post-fix remote Mac rail result remains
unverified until the existing Mac session is restored —
[QA-291](../evidence/flutter/qa291-flutter-selected-screen-rail-thumbnail-2026-10-05-001.json).

## Android receiver FPS comparison (FV2-036)

A user-provided side-by-side comparison of one screen stream reported 51.5 decoded /
52 FPS on macOS, 52 FPS in Web, and 21.7 decoded / 21 FPS in Flutter Android,
with 58 frames skipped in the Android interval, about 2 Mbit/s received and no
packet loss at a selected 1080p/60 profile. This points to the Android receive,
decode or render path only if the three clients were observing the same source;
the screenshot does not identify the publisher, exact client revisions, or a
physical device. QA-293 recorded an API 35 Emulator with package versionName
`1.0.34` and versionCode `2067`, with no active screen projection, so the
comparison could not be reproduced then.
After ADB access was granted, the emulator inventory was rechecked: the same
package version is installed, the launcher is foreground, and MediaProjection
is still null; there is no active receiver sample to compare in this session.

The Android WebRTC fork currently reports `DEFAULT_FPS=30` in captured track
settings, but its `OrientationAwareScreenCapturer` ignores the supplied capture
framerate; this value alone does not prove a 30 FPS transmission cap. Flutter's
receiver diagnostics now report separately sampled received, decoded and
rendered frame rates plus codec/decoder implementation when WebRTC exposes
them. This is local presentation only; no report or server/API contract changed.
The diagnostics tests, full Flutter suite, changed-file analyzer, Android Debug
and macOS Debug builds pass. GitHub CI also passed the contracts/traceability,
Flutter/Android Debug and Windows Release jobs. Keep the root cause open until a synchronized
Mac/Web/Android receiver run captures the same publication and sender/receiver
frame counters, followed by an emulator vs physical-device comparison —
[QA-293](../evidence/flutter/qa293-android-receiver-decoded-fps-parity-2026-10-05-001.json),
[QA-297](../evidence/flutter/qa297-flutter-android-receiver-diagnostic-breakdown-2026-10-05-001.json).

## TEXT visible read cursor ordering (FV2-037)

The server advances a channel cursor monotonically by the tuple
`(message_created_at, message_id)`. Web's visible-read gate follows the ordered
message list, while Flutter previously cached only `createdAt`; after reading
one message, a second visible message with the same timestamp was incorrectly
discarded locally. A test-first regression reproduced one advance instead of
two for `message-a` then `message-z`. Flutter now compares the same timestamp/ID
tuple both for confirmed and in-flight cursors, including out-of-order request
completion, without changing the API contract or web implementation. The focused
regressions, full Flutter suite, Android/macOS Debug builds and the full
GitHub CI run pass. CI retained both the Android Debug APK and Windows x64
Release distribution; server SQL ordering was inspected —
[QA-294](../evidence/flutter/qa294-flutter-text-read-cursor-order-2026-10-05-001.json).

## Attachment size rejection and failed queue (FV2-038)

The web upload queue retains every failed file, including a file rejected by
the local 25 MB limit, so the user can remove it or retry after correcting the
problem. Flutter previously displayed the size error but discarded the source
for both native file selection and clipboard-image paste. Both paths now use
the common upload validation and preserve locally rejected sources in the
actionable failed queue. Regression tests first reproduced the missing chips;
the complete attachment-composer test file now passes —
[QA-295](../evidence/flutter/qa295-flutter-attachment-size-failure-queue-parity-2026-10-05-001.json).

## Attachment size error copy (FV2-039)

The web upload client presents the same restriction message for an invalid file
name/size: “Файл не соответствует ограничению вложения.” Flutter previously
used a more specific 25 MB message for its local size check. To keep cross-client
feedback identical, the Flutter file-picker and clipboard-image paths now use
the web copy. Both size-rejection widget cases assert that visible message —
[QA-296](../evidence/flutter/qa296-flutter-attachment-size-copy-parity-2026-10-05-001.json).

## Client update awareness

Web, Android and Windows use independent release identities with shared policy
states and language-neutral evaluator fixtures. Each surface provides a root update banner,
details, snooze and manual check. Web performs a guarded reload; native clients
open an explicit external download page and leave active media intact until the
user decides. Automated contract and build gates are separate from the pending
two-release physical A/B acceptance recorded in
[QA-226](../evidence/flutter/qa226-client-update-device-acceptance-2026-10-02-001.json).

Desktop update-banner follow-up (FV2-040): long changelog summaries are now
limited to two lines with ellipsis in the banner; the full summary remains in
“Что нового”. Explicitly removing text decoration also avoids the underline
visible in the supplied Windows screenshot. A widget regression checks
1280×900 with text scale 2.5 and keeps the banner below 220 px. The shared
Flutter package bump to `1.0.35+68` was synchronized with all native platform
build identities at r49; native Windows visual acceptance remains pending —
[QA-299](../evidence/flutter/qa299-windows-client-update-banner-responsive-2026-10-05-001.json).

## Flutter noise-suppression runtime states (FV2-045)

The Flutter audio settings now distinguish unverified/idle, waiting for capture,
native-confirmed RNNoise activity, confirmed standard-engine fallback,
unsupported processing and microphone-stopped error states. The UI no longer
uses “Работает” for an unverified mode. RNNoise is called active only when the
current request matches the native report, `effectiveMode` is `rnnoise`, at
least one frame was processed and no native failure reason is present. A stale
runtime report from the previous selected mode is hidden until the new request
is confirmed. Apple’s coupled AEC/NS reason no longer claims standard fallback
before capture commits it. Focused widget/native-state tests include compact
320 px layout at 2× text scale; macOS/Android builds and physical native capture
acceptance are recorded separately in
[QA-304](../evidence/flutter/qa304-flutter-noise-suppression-runtime-states-2026-10-06-001.json).

## Flutter desktop microphone route selection (FV2-052)

Changing the microphone on macOS/Windows uses LiveKit's
`Room.setAudioInputDevice`, which selects the native Audio Device Module route
and updates the room defaults. With a published local microphone track, Flutter
also updates the track's capture options so later processing restarts retain
the selected ID. The connected-listener path (no local microphone track) uses
the same native route and updates the defaults for later publishing without
opening a capture. Desktop no longer relies on rebuilding a `getUserMedia`
track, while Android/iOS keep their capture-restart path. Regressions assert
the native `selectAudioInput` call, updated options, and unchanged capture
count; native-device acceptance is tracked separately in
[QA-311](../evidence/flutter/qa311-flutter-desktop-microphone-route-2026-10-06-001.json).

The 2026-10-06 muted Mac listener follow-up confirms runtime device inventory
changes from the system-only pre-join selector to two physical input choices
after voice admission. HyperX was selected and restored to the system input;
the microphone remained disabled and the temporary room session was closed.
This was a UI/inventory check in an already running app whose build/source
identity was not established at the time. A later live profile audit found that
the running GUI reports `Версия 1.0`, while the source at that audit was
`1.0.36 (69)`; source has since advanced to `1.0.37 (70)` and the open Mac
binary has not been rechecked. The QA-315 observations therefore do not prove
runtime behavior of the current binary. The UI check also does not verify that the native capture route changed;
do not enable the microphone without explicit approval. The stale-runtime
finding and current verification boundary are recorded in
[QA-315](../evidence/flutter/qa315-macos-muted-listener-audio-route-2026-10-06-001.json)
and [QA-316](../evidence/flutter/qa316-flutter-native-runtime-identity-audit-2026-10-06-001.json).

Windows' native selector previously ignored the return value from
`AudioDeviceModule::SetRecordingDevice`, allowing Flutter to persist a device
selection even if the Windows audio module rejected the route. The native
bridge now reports failed enumeration and route changes instead of returning
success, with a C++ mapping regression attached to the Windows plugin build.
LiveKit also updates its cached selected input only after the native method
succeeds, so failure keeps its cache, room defaults and Flutter selection on
the prior device. The Flutter regressions cover success, native rejection,
enumeration failure, rollback and no extra microphone capture on Windows and
macOS. Physical route acceptance and a Windows CMake build remain open —
[QA-317](../evidence/flutter/qa317-windows-native-audio-route-result-2026-10-06-001.json).

The availability follow-up observed Android 1.0.37 (2070) audio-settings
navigation, device selectors and scrolling on the ARM64 emulator. The existing
Mac debug app already listed both physical inputs before joining voice, unlike
the earlier QA-315 observation. Hot-reload attachment did not establish a
connection and later Mac UI actions left the screen unchanged, so neither
current-source nor native-route acceptance is claimed. The app was not restarted
and microphones remained off —
[QA-318](../evidence/flutter/qa318-macos-android-audio-settings-runtime-2026-10-06-001.json).

## Flutter audio settings feedback (FV2-046–047)

Manual microphone gain remains visible and stored while AGC owns the live
level; its control is disabled with an explanation and returns at the saved
value when AGC is switched off. Speaker-check feedback is cleared whenever the
selected output changes, and a delayed result from the previous output is
discarded. Widget regressions cover both transitions without opening a
microphone or changing a hardware route —
[QA-305](../evidence/flutter/qa305-flutter-microphone-gain-agc-2026-10-06-001.json),
[QA-306](../evidence/flutter/qa306-flutter-speaker-check-output-change-2026-10-06-001.json).
On the Android API 35 emulator, release `1.0.35+2069` visually confirmed the
saved manual value remains visible while AGC is enabled, the slider is disabled,
and the automatic-control explanation is present. No setting or audio route was
changed. Desktop visual acceptance remains open.

## Flutter audio settings responsiveness and accessibility (FV2-048)

At compact widths, the microphone activation choices remain horizontal at the
normal text scale and stack vertically when enlarged text would otherwise clip
their labels. Voice Activity Detection and Push to Talk are keyboard-focusable
buttons with explicit selected state; sensitivity exposes its dBFS unit in the
accessible value. Widget tests exercise enlarged text, compact width, short
windows, landscape geometry, keyboard traversal, activation semantics and the
sensitivity value. Workspace tests (77), the full Flutter suite (669), changed-
file analysis, and macOS/Android Debug builds pass. Native VoiceOver/TalkBack
acceptance is still pending — see
[QA-313](../evidence/flutter/qa313-flutter-audio-settings-responsive-accessibility-2026-10-06-001.json).

## Flutter desktop voice shortcut density (FV2-049)

On desktop, each shortcut row keeps the action name on the left and places its
current binding plus assign/clear controls on the right. Compact mobile layouts
retain the existing vertical presentation. Desktop/mobile widget regressions,
the workspace card geometry check, the full Flutter suite (670 tests), changed-
file analysis/formatting, and macOS/Android arm64 Debug builds pass. Android API
35 Release `1.0.35+2070` was installed in-place; a 1080×2400 screenshot confirms
the compact audio settings and vertical shortcut rows remain unchanged. Live
visual acceptance of the new desktop row on the current Mac process is still
pending because that process does not support hot reload and was not restarted —
see [QA-314](../evidence/flutter/qa314-flutter-shortcut-row-density-2026-10-06-001.json).
The QA-316 snapshot's Mac GUI reported `Версия 1.0` while source then was
`1.0.36 (69)`; source is now `1.0.37 (70)`, and current Mac visual acceptance
remains open. Android API 35's `1.0.35+2070` screenshot was built from source
revision `ca03c226`; production Flutter UI code is unchanged since then, so
that historical Android visual acceptance remains applicable. ADB currently
reports no connected emulator; QA-316's Accessibility Suite notification prompt
is a historical observation — [QA-316](../evidence/flutter/qa316-flutter-native-runtime-identity-audit-2026-10-06-001.json).

## Flutter playback volume reset placement (FV2-050)

The per-device reset for remote participant and screen-share playback volume is
now presented in its own “Воспроизведение” card, separate from microphone
processing and its collapsed diagnostics. The existing reset callback, busy
state, persistence and warning behavior are unchanged. Widget coverage checks
the card relationship at desktop and compact widths and ensures the action stays
available while advanced microphone processing is collapsed. Android API 35
release visual acceptance confirms the section is distinct and legible at
1080×2400; macOS Debug build passes, while the locked Mac prevented a live
desktop screenshot — see [QA-312](../evidence/flutter/qa312-flutter-playback-volume-reset-placement-2026-10-06-001.json).
