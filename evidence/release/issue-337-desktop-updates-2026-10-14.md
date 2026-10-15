# #337 — desktop update implementation and release acceptance

Started 2026-10-14; ongoing 2026-10-15. Candidate branch
`codex/issue337-desktop-updates`, based on `3e6ac963`. This is an implementation
record, not release approval. No production catalog promotion has occurred.

Publisher: locally generated Ed25519 root `boohtacord-desktop-478919e9652ab825`.
Private key is outside the repository with mode 0600, parent 0700. Only the public
root is a client asset. Apple signing identities are not used for update trust.

Adapters: Sparkle 2.10.0, Velopack native C API/packager 1.2.161, exact official
SDK archive SHA-256 pinned in the restore tool and ADR-027. macOS sandbox remains
on. macOS OS signature remains ad-hoc; Developer ID/notarization is not claimed.
Windows Authenticode is measured by existing packaging tools, not assumed.

## Checks performed so far

- PASS: publisher roundtrip/tamper/publication/CAS/key-preservation tests (3).
- PASS: focused Flutter update, checkpoint, archive, controller and draft tests
  (47 at initial integration; further regression cases being added).
- PASS: first universal macOS release builds including Sparkle and compiled
  recovery helper. Build output alone does not establish installation acceptance.
- PASS: contracts gate: OpenAPI 3.1 lint, 19 parity tests, 108 public operations.
- PASS: spec traceability: 39 requirement IDs (approved repository index).
- PASS: Go catalog/telemetry focused tests and go vet.
- Backend broad run on macOS: 1249 PASS, 5 FAIL, no skipped test cases. The five
  load-fixture tests bind additional 127/8 source addresses unavailable by default
  on macOS. The same two packages PASS on Linux Go 1.26.4 in an ephemeral container.
  This is a host fixture limitation; no load/capacity claim is made.
- Full Flutter regression found a resize-position regression in anchor restoration;
  corrected by distinguishing in-process layout memory from disk restoration.
  Focused resize regression PASS; subsequent full rerun PASS: 1370 cases,
  one pre-existing explicit skip. Final added window-bounds guard also covered
  by the focused update/workspace suite: 146 PASS.

## Required release gates still pending

| Gate | Status |
|---|---|
| Flutter regression and analysis | PASS locally and in CI at `34274936`; 27 current desktop-focused cases |
| Windows native build + per-user Setup/full package | PASS run 38688760886; retained and verified |
| Actual installed macOS N → N+1 with UI/state restoration | FAIL first attempt; monitor fix built, repeat pending |
| Actual installed Windows N → N+1 with UI/state restoration | NOT_RUN |
| Failed-bootstrap/apply recovery on both operating systems | Windows native component PASS; complete two-OS gate pending |
| Web, Android, iOS rebuilds and backend build | PASS compilation; iOS is unsigned, not an IPA/TestFlight delivery |
| Published immutable packages + signed metadata + catalog promotion | NOT_RUN |

Do not close #337 or describe in-app desktop updating as accepted until the real
OS gates above pass. Unit tests and native compilation do not replace them.

## Follow-up observations (2026-10-15)

- Public draft PR #338 retains implementation for native CI, not acceptance.
- First Windows run exposed asynchronous writer-lock cleanup (OS error 32).
  Closing is now awaitable/coalesced and the regression teardown waits for it.
- Full tools regression: 434 PASS. Feature/UI import boundary check PASS after
  moving AppState integration into `app/desktop_updates`.
- Added ZIP local/central-name agreement and extra-field restrictions before
  extraction, credential-free HTTP retry/Range tests, Windows baseline file
  hashes, and running/declaration package-identity conflict rejection.
  Current desktop-focused suite: 25 PASS on macOS.
- Web: 1530 tests PASS; production build PASS using explicit public origin.
- Backend: native `go build ./...` PASS; Docker image build PASS,
  local tag `boohtacord-issue337-api:3443928049c1` (not deployed).
- iOS 1.0.43 (78) device release compilation PASS with `--no-codesign`;
  this is not a signed IPA/TestFlight publication.
- Local Android release build stopped because the previous Android signing key
  is absent on this Mac. The candidate workflow uses existing repository signing
  secrets; no replacement/debug signing identity is substituted.
- Isolated macOS baseline installed under `~/Applications/BOOHTACORD-337-QA`.
  Actual authentication/state-restore acceptance currently awaits the user's
  system Keychain confirmation. Computer Use rejects SecurityAgent access;
  no security bypass was attempted.
- No genuine installed N → N+1 or rollback gate is PASS yet.

## Latest build observations (2026-10-15)

- Product-source candidate `3427493618ec2e6c6c9b084827ea886ea64a4036`:
  universal macOS ZIP built, whole bundle re-sealed and verified, signed metadata
  produced separately for arm64/x64 using the locally retained publisher key.
  The actual ZIP passed the client's signature/digest/extraction code and nested
  codesign afterwards. Sparkle 2.10.0's upstream native Ed25519 verification
  accepted its archive signature and rejected a changed signature. These are
  package/component checks, not an installed-client upgrade.
- Four native macOS monitor preflight tests PASS with real ad-hoc signed fixtures:
  writable-parent cancellation, denied replacement directory, missing directory
  and invalid invocation. The app, monitor and Sparkle are all universal; embedded
  trust root and expanded sandbox Mach service entitlements were inspected.
- A malformed resumed HTTP 206 with a changed ETag now discards both partial bytes
  and validator before a bounded full retry. Its regression failed before the fix
  and passed afterwards. Desktop-focused suite: 27 PASS.
- Local tools/contracts suite: 442 PASS, OpenAPI parity: 19 PASS. CI run
  [38649725893](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38649725893)
  passed contracts, Linux backend, Vue, Flutter/vendor tests and analysis.
- Signed Android candidate run
  [38649718967](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38649718967)
  PASS. All three retained APKs were independently checked with apksigner/aapt:
  original release certificate, `ru.boohtacord.app`, 1.0.43, expected ABI version
  codes 1078/2078/4078, full source-bound manifest hashes. No new Android key.
- Web production build, native Go build and local API Docker image build PASS.
  Image `86e6163bb009`, local tag `boohtacord-issue337-api:3427493618ec`.
  iOS release device compilation PASS with `--no-codesign`.
- Windows Flutter release compilation PASS in job 116145477829. Packaging then
  failed because pinned Velopack 1.2.161 does not expose `--version`. The packager
  now measures the installed tool through `dotnet tool list --tool-path`; focused
  tests cover the exact version and rejection of a different version. The native
  recovery component gate remains pending packaging; no fabricated ACK is used.
- Separate autonomous lifecycle run
  [38649725629](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38649725629)
  FAIL: no `roster-unavailable` event observed within 15 seconds after stopping the
  owned SFU. This failure was retained without weakening the check. Its cause has
  not been established by a baseline reproduction.
- Actual macOS UI acceptance is BLOCKED while the Mac is locked and system
  Keychain access requires user action. SecurityAgent automation is denied by
  Computer Use. Windows N → N+1/UI restoration is still NOT_RUN. Production
  catalog remains revision 29, PR #338 remains a draft, and #337 stays open.

### Follow-up: 2026-10-15, native recovery and isolated acceptance

This section supersedes the earlier pending Windows packaging and locked-Mac
status. It does not certify the full installed upgrade gates.

- Windows component gate PASS at `8cffb9fa8d7f324dcfce700e68b79ad85bf473ed`,
  [run 38687983343](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38687983343),
  job 116267141330. The shipping monitor used its actual 120-second deadline,
  restored every retained real Flutter app file, launched that executable, kept
  the synthetic external profile intact, removed its RunOnce registration and
  treated a replay of the finished transaction as a no-op. This is a failed-apply
  recovery component gate, not an installed N → N+1 UI/state acceptance.
- Native Windows regression checks PASS for Unicode/spaces, repeated extended
  paths, long paths, canonical parent identity, scope boundaries, sibling
  rejection and POSIX-separated names in the retained-file manifest. Recovery
  now resolves 8.3 aliases consistently with long paths before scope checks and
  normalizes paths before opening retained files.
- Actual PE imports exposed a missing canonical `velopack_libc.dll` loader name.
  The build now supplies that name from the pinned verified SDK and checks the
  reachable native dependency graph. The retained historical app fixture used
  by the fast gate is manifest-verified before adding the canonical loader alias;
  that historical installer itself must not be promoted as healthy.
- The runtime catalog's optional `install_artifact` schema reference initially
  pointed at a misplaced definition. New regression tests failed on resolution
  and on accidental acceptance of an internal camel-case field. The definition
  is now in `$defs`; both tests and publisher signing tests PASS (5).
- Local complete contracts/tools gate PASS: 447 tests, 19 OpenAPI parity tests,
  39 requirement references. Approved brief remains unavailable on this host;
  the verifier reports that limitation. Reachable integration-test helpers are
  now checked by the Dart import graph; production imports of QA remain forbidden.
- User unlocked the Mac and granted native Keychain access. The installed normal
  candidate connected. A separate installed beta 1.0.43 (78) now uses the actual
  API and native secure storage against an owned loopback HTTPS/PostgreSQL/SFU
  stack, separate preference prefix and secure-storage namespace. No production
  cookie was read/copied for this acceptance. Three namespace-isolation tests and
  focused analysis PASS. A synthetic channel/draft was prepared through the UI.
- The QA N+1 app is built with the shipping application and updater through a
  separate entrypoint. Its private local configuration and local CA private key
  are never included in the app or public assets. The dedicated workflow publishes
  a fresh explicitly beta/prerelease artifact, never latest; publisher signing
  stays on this Mac. Production catalog remains revision 29.
- macOS installed N → N+1, failed-bootstrap rollback, Windows installed N → N+1
  and UI/state restoration remain NOT_RUN until their actual observed results
  are recorded. PR #338 stays draft and #337 stays open. The independent lifecycle
  failure above has not been waived or established as pre-existing.


## Installed macOS attempt and fresh Windows artifacts (2026-10-15)

- Real isolated installed macOS beta 1.0.43 (78) authenticated against an owned
  HTTPS Go API/PostgreSQL stack using scoped native Keychain storage. Published
  CI package 1.0.44 (79) downloaded and reached Ready. Later kept the app running;
  the existing draft remained visible, and a later draft edit was made before
  the explicit restart confirmation.
- Actual apply attempt FAIL before replacement: the sandbox-created monitor copy
  had quarantine flags and macOS refused execution. No bootstrap ACK or completed
  outcome was fabricated; the installed bundle remained build 78. Failed journal
  and artifacts are retained locally. This is not an accepted upgrade.
- Fix: launch the monitor sealed in the installed bundle. After apply consent,
  that monitor validates the installed bundle and retains its baseline and helper
  itself, then registers the retained executable for recovery. No quarantine
  flags or OS protections are disabled. Six real native macOS preflight tests
  PASS, including retained whole signed baseline and embedded monitor identity
  rejection. The rebuilt isolated beta78 is awaiting native Keychain permission
  for another live attempt.
- Fresh full Windows job 116269703551 in
  [run 38688760886](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38688760886)
  PASS: native compile, required DLL dependency graph, per-user Setup and full
  NUPKG. Retained source merge SHA `7c9474df66fa9912af51fc333d756616a5e69758`.
  Downloaded artifacts 11951762001, 11952181829, 11951537139; archive hashes and
  all 53 native manifest file hashes verified independently. Canonical
  `velopack_libc.dll` is present in the app and the full package.
- Fresh Windows recovery evidence PASS: actual monitor, 124 seconds, whole
  baseline hashes preserved, real Flutter relaunch, Unicode paths, external
  synthetic profile retained, completed transaction replay no-op, one-shot
  registration removed. N-to-N+1 UI acceptance remains NOT_RUN.
- Fixed beta/development Velopack feed selection and misleading manual-recovery
  UI; added focused regressions. Schema tests now use the CI unittest runner,
  without an unavailable pytest dependency. Tools/contracts: 451 PASS locally;
  OpenAPI parity: 19 PASS; traceability: 39 repository-index requirements.
- Independent lifecycle run 38688760738 still fails the unchanged 15-second
  roster-unavailable SSE gate. Added bounded event-transport diagnostics only;
  no payloads/identities retained and no deadline or assertion weakened.


## Workspace restoration and SSE isolation follow-up (2026-10-15)

- Added failing regressions for delayed workspace restoration overwriting fresh
  panel/search/scroll/audio choices, missing persistence after restore, mutation
  after disposal, unchanged-snapshot retry after a failed save, and restart
  checkpoint retry after an earlier background failure. All are now PASS;
  complete focused desktop/draft/workspace screen suite: 136 PASS. Scoped Dart
  analysis: no issues. Existing encrypted/account-scoped storage remains in use.
- Latest tools/contracts run: 451 PASS; OpenAPI parity: 19 PASS. The SSE observer
  unit tests PASS and the actual media journey syntax check PASS.
- Browser run 38692019424 FAIL retains the original 15-second event assertion.
  Bounded diagnostics: 2 sources created, 2 opened, 2 transport errors, latest
  readyState CLOSED, zero roster-unavailable events, participants HTTP 503.
  The next journey additionally requires an OPEN roster stream before stopping
  the owned SFU; no post-fault assertion or deadline is relaxed.
- Independent real TLS wire probe against the owned Go API/Caddy/PostgreSQL/SFU
  delivered the actual roster-unavailable control event after SFU shutdown.
  The owned SFU was restarted in finally. This is a component result; it does
  not turn the failed full browser journey into PASS.
- Source 09e31d9a CI: contracts, Linux backend, Vue and Windows native monitor
  component PASS; signed Android candidate PASS. Full Windows app job and
  Flutter Android build-mode job are still running at this observation.
- macOS repeat remains waiting for native Keychain approval. Do not close #337,
  merge/promote production packages or claim either installed OS gate PASS.


## Container-home guard and actual banner rendering (2026-10-15)

- A clean restart after Keychain approval connected the QA78 client with its
  existing real session. A second download reached Ready; Later kept the client
  running, and a synthetic draft was changed after Ready before explicit apply.
  Actual apply again FAIL before replacement: no monitor-ready receipt appeared.
- Added a native regression with CFFIXED_USER_HOME/HOME pointing to a container.
  It reproduced helper exit 2: NSHomeDirectory incorrectly changed the permitted
  user installation prefix. The helper now derives the user's real home from
  getpwuid(getuid()) for plan/installation checks and LaunchAgents. Seven native
  preflight tests PASS. Actual installed upgrade remains unaccepted.
- Visual inspection found the update banner inheriting Flutter's red/yellow
  48-point error text style outside a Material ancestor. Three regressions
  reproduced that rendering at the real standalone banner/panel boundary. Both
  components now supply transparent Material typography. Focused update,
  draft and workspace suite: 167 PASS; scoped analysis: no issues.
- Rebuilt QA78 with these fixes. A local Apple Development signing experiment
  stalled in libsecinit_appsandbox before main/window startup, with AppleEvent
  timeout -1712. No permission/entitlement was widened. The pre-main owned QA
  process was terminated with SIGTERM; the established ad-hoc signatures were
  restored and strict nested verification PASS. The system launch remains
  blocked pending the user's response to any outstanding container dialog.
  Do not treat this attempt as a completed update or migration.
- Tools/contracts: 452 PASS, OpenAPI parity: 19 PASS. Added two privacy regressions
  for bounded roster diagnostic metric parsing; all seven Node QA tests PASS.
  Future failed browser journeys retain only fixed enum/count metrics from their
  owned loopback API, not raw telemetry or identifiers. The unchanged full SSE
  gate still FAIL in run 38736051523, even with an OPEN stream before injection.
- Source 1cdf2b46 full CI 38736051682 PASS across contracts, backend, Vue, Flutter
  and Windows. Native candidate run 38736045575 PASS. New home/typography fixes
  require the next source-bound native builds and live acceptance.

## Responsive browser fault injection and rebuilt clients (2026-10-15)

- The failed full browser journey used synchronous Docker stop/start calls in
  the Playwright driver. Docker's graceful SFU shutdown blocked that driver's
  WebSocket proxy and request callbacks. Replaced only SFU fault control with
  asynchronous execFile calls; exact container name and owner-label checks
  remain mandatory. Three new focused tests cover event-loop responsiveness,
  foreign-resource rejection and invalid owner/action rejection. Ten Node QA
  tests PASS. The original 15-second roster-event assertion is unchanged.
- Actual local TLS/API/PostgreSQL/LiveKit/Tempo browser journeys PASS at both
  1440 and 1024, using the changed driver on product source 30ad2bfc. Real
  roster-unavailable events were observed after SFU shutdown; chat-only failure
  kept real WebRTC alive, targeted recovery succeeded and owned resources were
  removed. Reports include source digests. Inspected both actual SFU-failure
  screenshots: readable status and retry action, retained participants, no
  misleading empty-room state. This is local evidence; the new Linux CI
  journey has not yet run and earlier failed runs remain FAIL.
- Full source-30ad2bfc CI
  [38739317432](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38739317432)
  PASS across contracts, backend, Vue, Flutter and Windows. The Windows job
  built the real app, per-user installer and full package, and passed the
  native absent-replacement recovery/relaunch component gate. This does not
  establish installed N-to-N+1 acceptance.
- Signed Android candidate run 38739308401 PASS. All three downloaded APKs
  independently pass apksigner verification with the existing publisher
  certificate, application ID ru.boohtacord.app and version 1.0.43; ABI version
  codes are 1078/2078/4078. Workflow archive and manifest hashes were verified.
- Ordinary universal macOS 1.0.43 (78) rebuilt from clean source 30ad2bfc.
  Packaged ZIP: 47,347,184 bytes; SHA256
  8cc944f07ffc98c8c01df0e22787c53d456b96b5e1597f9d3a1f0e2a1762bc5b.
  Source manifest, archive contents and strict nested ad-hoc signature verified.
  Packaging initially refused a leftover local Development signature after
  rebuilding nested code; the known owned build candidate was explicitly
  returned to the established ad-hoc identity and verification rerun. No
  Developer ID or notarization claim is made.
- iOS device Release compile PASS from 30ad2bfc with --no-codesign: version
  1.0.43 (78), application ID ru.boohtacord.app. This is an unsigned app build,
  not an IPA or TestFlight delivery.
- Isolated macOS QA launch remains BLOCKED before main in
  libsecinit_appsandbox after restoring ad-hoc signing. A sample confirms no
  application window/bootstrap started; the exact owned stalled process was
  stopped with SIGTERM. Security dialogs remain user-operated. No container
  data, permissions, trust settings or OS protections were reset. Installed
  macOS update and Windows N-to-N+1 acceptance remain unproven; #337 stays open
  and production catalog revision 29 is unchanged.

## Linux fault scope diagnosis (2026-10-15)

- Linux lifecycle run 38742662353 still FAIL with asynchronous Docker controls;
  local macOS PASS did not establish the Linux gate. Reproduced that failure
  using the actual production browser journey in a separate owned Linux
  Chromium container on this Mac, with the real bridged TLS/API/SFU stack.
- New bounded diagnostics distinguish a native transport failure from an
  explicit client close. Observed latest_closed_by_client=false,
  ERR_NETWORK_CHANGED, subsequent roster HTTP 503 and the workspace still
  mounted. Docker stop removes a network interface on the Linux browser host;
  Chromium aborts unrelated open streams before the SFU control event arrives.
  The actual failure screenshot shows the unavailable roster/retry UI, not an
  empty-room success. No private response/error text is retained.
- Changed this isolated dependency-fault injection to pause/unpause only the
  exact owner-labelled SFU. Its real process is suspended, so the actual API
  must detect the unavailable dependency; its network interface remains intact.
  The unchanged 15-second event assertion, UI checks, media teardown and
  targeted recovery checks remain mandatory. No browser network behavior,
  production code, timeout or assertion was disabled to obtain a result.
- Fourteen focused Node tests PASS, including explicit rejection of stop/start
  in this fault controller, foreign-resource protection and bounded browser
  network diagnostics. The actual Linux 1440 journey now PASS end-to-end,
  including media failure/recovery, real Tempo verification and owned-resource
  cleanup. Report SHA256:
  3778c10f1bf736399daab6a3c08a85d88c9677ad00efe9d4aadafc31ce3f3297.
  Its screenshot was inspected: readable unavailable status/retry, muted state
  and retained local participant; no fabricated empty-room status.
- The first local Linux 1024 follow-up stopped before the scenario at the
  initial login's unchanged five-second app-shell assertion. It remains FAIL;
  no roster/media acceptance was obtained from that run. A fresh isolated
  repeat PASS at 1024 with all assertions unchanged, real media/Tempo checks
  and owned-resource cleanup. Report SHA256:
  eead1992efa8a21539a60ba55cc264b16065c5e6544ee9396447f9750c9a87c9.
  The actual 1024 screenshot was inspected: readable roster age/retry, retained
  muted local participant and no empty-room success. The next independent CI
  journey is still pending at this observation.

## Connected macOS repeat and independent CI results (2026-10-15)

- Full source-d4b5af51 CI 38745575364 PASS: contracts, backend, Vue, Flutter and
  Windows, including the real recovery/relaunch component and installer build.
  Product sources are unchanged from the independently verified 30ad2bfc
  client packages; subsequent changes affect the acceptance driver/evidence.
- Independent browser CI 38745575464 attempt 1 passes the previously failing
  roster-event gate, then FAIL at lease-notification delivery during blocked
  REST: zero observed WS hints within the unchanged 20-second deadline, outbox
  pending=2/claimed=0/emitted=1 and zero connected transports. The unchanged-code
  rerun FAIL earlier, at initial login's five-second app-shell assertion. Neither
  attempt establishes full acceptance; no backend cause is asserted.
- Added failed-login diagnostics with numeric status and fixed UI booleans only.
  Failure captures mask every input/textarea; raw credentials, bodies, URLs and
  cookie values are not retained. Three focused regressions PASS, including
  preserving the original assertion if capture fails. Seventeen Node QA tests
  PASS. Added only aggregate pending-kick/queue-age data to the existing owned
  notification-failure query. All acceptance deadlines/assertions are unchanged.
- After the user's system-dialog actions, the exact isolated QA78 app connected
  with its existing real account/session. Actual visual inspection confirms
  normal compact Material typography in the update banner and status card.
  Download/verification reached Ready; Later left the client running, a real
  draft was changed after Ready, and declining the restart confirmation retained
  the prepared package. No synthetic draft body is copied into this record.
- Actual apply attempt 3 FAIL before replacement: after explicit confirmation,
  the UI showed state saving, then a safe preparation failure with Retry. The
  installed bundle still reports 1.0.43 (78); no new-version launch is claimed.
  The user reports another system request; its exact text is pending. Reading
  this application's protected container from the shell was denied by macOS;
  no alternate access, permission reset or bypass was attempted. Recovery
  receipts are therefore unobserved, rather than assumed absent.
- The source remains ad-hoc signed; it was not changed again during this repeat.
  macOS N-to-N+1, Windows N-to-N+1 and production promotion remain unaccepted.
  Issue #337 stays open and PR #338 stays draft.

## Failed apply retains a connected workspace (2026-10-15)

- Source-ffeecfef full CI 38755510496 PASS across contracts, backend, Vue,
  Flutter/Android modes and Windows packaging/recovery. Independent lifecycle
  CI 38755510212 PASS, including both real TLS/API browser journeys and actual
  attachment-reservation/single-writer checks. Earlier intermittent login and
  notification failures remain recorded; this pass does not prove their cause.
- After macOS attempt 3, the actual composer still visibly retained the late
  draft. Presence became unknown after graceful shutdown. Source inspection
  confirmed that the retained client never reconnected realtime on failed apply.
  No draft body is retained in evidence; no draft-loss conclusion is made.
- Added focused regressions before implementation: failed synchronous/asynchronous
  native apply must resume background connectivity exactly once; failures before
  shutdown do not resume it; a changed account/session, disposed workspace and
  stale cleanup from an earlier retry cannot affect the current session. Tests
  also reproduce a shutdown background flush overwriting saved mute/deafen with
  the temporary values set by leaving voice.
- On failed apply, the same active origin/account/session now reconnects realtime
  and retains prior audio intent, unless the user has since changed it. Voice
  and screen sharing are not restarted. Persistence is suspended during consented
  shutdown so its temporary media state cannot overwrite the fresh checkpoint;
  failed-apply recovery resumes ordinary saving. A native error arriving before
  apply returns cannot be overwritten with the Restarting state.
- Validation: 84 update/realtime Flutter tests PASS; focused analyzer reports
  no issues. The shutdown-flush and stale-cleanup regressions failed before
  their fixes, then passed with the existing tests.
- These focused/component checks are not a successful installed N-to-N+1 run.
  The system request's exact text remains pending; no signing identity, OS
  security policy, protected container permission or production catalog changed.

## Native LaunchServices handshake regression (2026-10-15)

- Added a real NSWorkspace launch test before changing the monitor. It launches
  the genuinely signed embedded monitor from an owned temporary app, using only
  a synthetic local plan and deliberately cancelling the fixture afterward.
  It does not access the installed QA profile or create a login registration.
- The old monitor completed preflight and wrote recovery-ready.json, yet the
  caller timed out waiting for LaunchServices to report a started application.
  A directly executed command-line preflight did not cover this failure mode.
- The background monitor now completes Cocoa initialization with finishLaunching
  and services its main run loop while waiting. It remains prohibited from
  activating a foreground UI. The new launch callback test now PASS, and all
  eight native preflight/retention/cancellation tests PASS in 3.245 seconds.
  See Apple's [finishLaunching documentation](https://developer.apple.com/documentation/appkit/nsapplication/finishlaunching()).
- This establishes the isolated launch-handshake regression and its fix. It does
  not identify the user's current security dialog or prove a successful installed
  app upgrade. Those observations remain pending independently.

## Live repeat after user screenshot (2026-10-15)

- The supplied screenshot shows the normal client, not a system request. The
  dialog-text wait is resolved. The old test app's unknown-presence state and
  visible late draft were confirmed. Its exact process was closed normally;
  the repaired QA78 bundle replaced only the owned test app, with prior bundles
  retained and no protected profile/permission changes.
- Account and channel restored and real presence became Online. The previous
  late draft was empty after replacing the old baseline: retain this as FAIL.
  A fresh synthetic draft on the repaired baseline then survived an ordinary
  close/relaunch, visually verified. No body is copied into this record.
- Full source-887cc904 CI 38760035022 PASS. Signed Android candidates pass
  independent APK signature, identity, ABI-build and manifest checks. All 53
  Windows manifest files match the full NUPKG; Setup and canonical SDK DLL exist.
  Artifact source 330e8320 is the verified merge of master 3e6ac963 and 887cc904.
  Real native Windows recovery/relaunch passes in 124 seconds. Installed Windows
  N-to-N+1 UI acceptance remains NOT_RUN.
- Latest browser lifecycle 38760034617 attempt 1 passes the complete 1440 journey
  and Tempo checks, then FAIL at the initial 1024 login. Its masked capture shows
  Failed to fetch; bounded diagnostics show login_status=null, session_status=200,
  workspace_present=false and form_error_present=true. No cause is asserted;
  earlier complete PASS 38755510212 remains historical. An attempted isolated
  rerun received a connector transport error and was not assumed dispatched.
- QA79 run 38760026200 initially could not obtain a runner and was cancelled
  before any steps. Its isolated retry passes native tests, builds and publishes
  the source-887cc904 prerelease. Published ZIP is 47,460,038 bytes, SHA256
  1c4be0406b1c96e975699513e9227be05927a729fef920c48dd01d7b9d65aee0.
  Downloaded bytes, strict bundle signature and identity pass. Publisher-envelope
  verification and the actual pinned Sparkle verifier pass; the key remains local.
  Only the private owned QA catalog changed to revision 3. Production remains 29.
- The native client downloads that real target in the background while a real
  voice connection remains active, with microphone and incoming audio disabled.
  Navigation and draft editing work during download; actual server active-lease
  count is 1. No media payload/capacity claim follows from this listener session.
- Preparation still FAIL after download. The same Dart verifier/extractor and
  strict codesign pass independently on the published package. Added bounded
  support codes in About after failing tests, preserving only known native
  reason enums and never exception messages/paths. Actual About now identifies
  recovery_busy: an earlier cancelled, unstarted recovery plan blocked retry.
- New macOS retry cleanup uses the same BSD monitor lock and preserves its inode
  across attempts. It archives only cancelled or terminal inactive state; active
  monitors and unmatched cancellation remain blocked. No success receipt is
  synthesized. New plans have transaction-specific filenames, and monitors
  recheck the plan after locking. Retired copies are bounded to three; the next
  consented helper cleans matching old login registrations. Windows behavior is
  unchanged by this macOS-specific cleanup.
- 88 update/realtime Flutter tests PASS, focused analyzer has no issues, and
  14 native tests PASS (13-suite plus added unique-plan test). Native regressions
  cover actual cross-process lock refusal, unchanged lock inode, cancellation
  matching, bounded history and partial-cleanup retry. The launch test still
  requires a callback within five seconds; it now independently waits for real
  preflight readiness because launch completion can precede Ready.
- Actual retry on that same protected-profile installation now reaches Ready
  for the verified QA79 package. Only the application's ordinary retry code
  performed inactive-state retirement. No shell access to the protected cache,
  fabricated receipt, permission reset or profile deletion was used. The actual
  N-to-N+1 apply/relaunch is still the next gate.

## Sandboxed macOS launch failure and document handoff (2026-10-15)

- Full CI [38794373579](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38794373579)
  passes for `b2495833`: contracts, backend, Vue, Flutter/Android and Windows
  packaging plus actual recovery/relaunch. Independent browser acceptance
  [38794373277](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38794373277)
  passes on attempt 2; attempt 1 failed before a journey with Chromium
  `ERR_NETWORK_CHANGED`. The first failure is retained, not treated as an app
  behavior pass. Signed Android candidates also pass.
- Ordinary macOS `b2495833` package passes all source/manifest digests. iOS
  device Release compiles, unsigned; no IPA or TestFlight upload is claimed.
- Fresh immutable beta-only macOS 1.0.44 (79) package from `b2495833`:
  [QA release](https://github.com/Egkurilov/BOOHTACORD/releases/tag/qa337-macos-1.0.44-beta-b2495833a99984c25795a990de5869d4068464cb),
  47,472,021 bytes, SHA256
  `b41841ce02fa4f15862a74d1722f0320fc8deb513c6d9edd2a9165cfee72de2e`.
  Published bytes, ZIP CRC, strict nested codesign, bundle version, local
  publisher signature and actual Sparkle verifier all pass. Private owned QA
  policy advanced to revision 4; production policy remains revision 29.
- Actual installed QA78 rejects a previously prepared target after policy
  changes with `compatibility_changed`, before shutdown; voice remains
  connected. An old cached archive is rejected with `digest`; retry downloads
  the fresh package. Actual 45.3 MiB background download, editing the unsent
  draft, Ready, Later and cancelling restart all pass while real voice remains
  connected with the microphone muted and incoming audio disabled.
- The subsequent real apply fails before replacement with `recovery_start`.
  QA78 remains installed. Fixed, bounded native diagnostics establish that
  the helper receives `argc=1`, with no plan argument. This matches Apple's
  documented [App Sandbox restriction on NSWorkspace arguments](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments).
  Earlier non-sandboxed native launch tests could not prove that boundary.
- The native bridge now opens only the owned recovery directory as a document
  in the exact embedded helper. AppKit's document event supplies the directory;
  a bounded local request binds its plan filename and transaction. The helper
  validates both, retains scoped access for its lifetime, and preserves the
  existing CLI path for resumed recovery. No sandbox, signature, Gatekeeper,
  quarantine or TLS protection is disabled. No protected profile is read or
  modified through the shell.
- The new real Cocoa document-handoff test fails before implementation and
  passes afterwards: launch, actual baseline retention, Ready and cancellation.
  Sixteen native tests pass, plus a focused native test rejecting an unowned
  directory, traversal and a changed transaction. Eighty-eight focused Flutter
  update/realtime tests pass; analyzer reports no issues. The Dart arm test
  first fails without `launch.json`, then passes with the matching request.
- Installed macOS N-to-N+1 and rollback remain unaccepted pending the next
  actual installed run with this bridge. Windows installed N-to-N+1 remains
  NOT_RUN. #337 stays open and PR #338 stays draft.

## Existing helper registration and a real sandbox parent (2026-10-15)

The installed document-handoff attempt still fails before replacement. Bounded
native NSError diagnostics establish Cocoa 256 with underlying OSStatus -10820:
`kLSAppDoesNotClaimTypeErr`, which the current Apple SDK describes as an
unsupported document type for sandboxed callers. The helper is executable,
strictly signed, and has no quarantine attribute; no attribute is removed.

A new native parent fixture runs with App Sandbox enabled and proves denial of
writes outside its own container. A unique compile-time test package identity
keeps this fixture separate from the real application's protected data. Only
the fixture itself reads/writes its new application-support directory; the
Python driver never reads an application container. The fixture also confirms
that registering the nested helper from the sandboxed parent returns -10819.
That rejected approach is not used in the shipping bridge.

The bridge now first launches the exact embedded helper without arguments.
Before completing Cocoa startup, the helper refreshes its own document claims
using the public LSRegisterURL API. Only then does the parent open the one owned
recovery directory in that running helper. The helper's bundle version advances
to 2. This updates its own registration and does not select a default handler,
change sandbox entitlements, grant broad filesystem access or alter OS trust.
Errors retain at most four fixed-domain/numeric underlying causes, without
paths, arguments, credentials or userInfo content.

All 18 native tests pass in 24.843 seconds, including actual sandbox enforcement,
the complete launch/document/Ready/cancel journey and independent path/identity
failures. The universal QA78 candidate compiles, packages and passes strict
nested codesign. A new installed run with a matching fresh QA79 is pending;
macOS installed-update acceptance is not claimed by these component tests.

## Actual macOS replacement and history restoration regression (2026-10-15)

- Source 747884d0: the real sandboxed installed QA client 1.0.43 (78)
  downloaded the signed immutable QA release and Sparkle replaced it with
  1.0.44 (79), launched from the same permanent user installation directory.
  The new version displayed the real completed-bootstrap banner. Account,
  server, selected text channel and exact unsent draft were retained, including
  changes made during download and after Ready. No draft body is logged here.
- The source application had a real SFU voice connection during download;
  Later/declining restart retained the live client. After consented restart,
  voice and capture did not silently start. Explicit listener-only rejoin
  connected successfully with both microphone and incoming audio still off.
- Native launch previously failed because a sandboxed NSWorkspace caller drops
  arguments, and the installed helper did not claim directory documents. The
  helper now registers only itself before Cocoa startup; its exact running
  instance receives the owned recovery directory as a document. Transaction
  identity and confined plan paths remain mandatory. Eighteen actual native
  monitor tests PASS, including an actual sandboxed Cocoa parent that cannot
  write outside its own fresh fixture container. No OS trust/sandbox settings,
  quarantine or protected-profile permissions were changed.
- The complete live macOS acceptance still FAIL: history opened at synthetic
  row 65 instead of row 39. This is retained as a regression, not represented as
  a full successful state restoration. Windows installed N-to-N+1 remains
  NOT_RUN; its real native recovery/relaunch component is not a substitute.
- Added a failing actual workspace widget regression before the scroll fix.
  History anchors were captured synchronously before lazy rows completed
  layout; initial automatic movement could also defeat a delayed disk import.
  Imported channel positions additionally lacked a scheduled restore frame.
  Capture now refreshes after layout, only user movement blocks disk restore,
  and imported positions explicitly schedule restoration and its next frame.
  The same behavior applies to DM history. Four cases cover delayed channel/DM
  restoration and an actual fresh user gesture winning over old disk state.
- Validation: 189 focused update, realtime and workspace tests PASS. One earlier
  invocation named a nonexistent test directory; it was corrected without
  changing assertions. Independent source-747 browser lifecycle CI
  38803225363 PASS; signed Android candidate and Windows recovery component
  38803217778 PASS. Final rebuilt installed-client verification is pending.
- Issue #337 remains open, PR #338 draft, production catalog revision 29 and
  master unchanged. Test prereleases do not become latest or production targets.

## Installed Windows gate and native API startup (2026-10-15)

- Added a release-mode Flutter integration entrypoint around the unchanged
  shipping main. Actual framework input drives voice/text, edits during real
  download and after Ready, decline/confirm restart and explicit voice rejoin.
  It compares draft/account/origin/channel digests, real visible-row geometry,
  window bounds and audio intent. It never writes bootstrap acknowledgements,
  successful recovery outcomes or simulated installer results.
- The native Windows gate builds actual per-user Setup 78 and full package 79.
  Source 7b6c787b published immutable beta release 414288660; package asset
  645210707 is 30,775,469 bytes, SHA256
  fca57dbf7017c115df024e4703b477410c3887cbeca886d1a278e2fbb1fa224c.
  Published digest/size, CRC, NUSPEC identity, native x64 executable, recovery
  helper, SDK and embedded publisher root were independently verified on Mac.
  Its Windows CRLF public-key file contains exactly the same two key lines.
  The owner signed the verified artifact locally; no private key entered CI.
- Only public nonexecutable signature metadata was then supplied for the
  already-running source-7b gate. Its original source/build checks continued;
  the data-only commit did not claim fresh code-validation results.
- Actual installed Windows acceptance remains NOT_RUN: run 38808113380 failed
  during native dependency startup, before installing the client. The generic
  diagnostic did not identify which process exited. Source inspection found
  a definite blocker: the API's non-Linux filesystem implementation always
  returns ErrInvalidSpace, so that API cannot start on native Windows.
- Added native Windows GetDiskFreeSpaceEx capacity measurement with bounds and
  cancellation checks, leaving Linux behavior unchanged. Focused Windows tests
  cover real temporary-volume capacity, invalid paths and cancelled context;
  cross-compilation PASS, actual execution awaits the Windows runner. The host
  package tests PASS. This does not advertise a Windows server deployment.
- Added a native-stack preflight before expensive client builds and bounded
  startup diagnostics (fixed role, numeric exit, enumerated reason only).
  Private service output and configuration remain outside uploaded artifacts.
  Six focused Python fixture tests PASS, including refusal to close an existing
  user installation and rejection of untrusted tool archive paths/digests.
- Ordinary universal macOS 1.0.43 (78) was rebuilt, strict signatures and all
  manifest digests verified. iOS device Release compiles unsigned; it is not
  an exported IPA or TestFlight upload. The second actual macOS 78-to-79
  replacement/local bootstrap succeeded; authentication is waiting for the
  new build's OS Keychain access, so final state restoration is still pending.
- No release acceptance, issue closure, master merge or production catalog
  promotion is claimed while these native gates remain outstanding.

## Final route/tab checkpoint audit (2026-10-15)

- Actual failing tests reproduced two additional restoration omissions: a DM
  navigation list with no selected conversation returned to channels, and an
  unmounted/remounted profile panel discarded its selected settings tab.
  A third widget regression confirmed an already mounted admin panel ignored
  a restored admin section. All three were observed failing before their fixes.
- Workspace checkpoints now include bounded profile/admin section enum names;
  no profile or password form contents are added. Admin section restoration
  requires the current administrator role. Choices made while disk reads are
  pending win, and workspace clear discards the former account's profile tab.
  Section changes notify ordinary persistence, not just update checkpoints.
- Validation: 121 focused update, realtime-scope, workspace, profile and admin
  tests PASS; focused analyzer PASS. An initial test command named a nonexistent
  `test/realtime` directory; the corrected `test/realtime_scope` run passed.
  A new admin fixture initially used `ADMIN` instead of the actual contract's
  `ADMINISTRATOR`; the fixture was corrected without relaxing production ACL.
- Source c8b7b5e3: full CI 38811407816 and browser lifecycle 38811407776 PASS.
  Actual native Windows filesystem tests and native PostgreSQL/API/TLS/LiveKit
  preflight in 38811398713 PASS. Signed Android candidate 12009470848 passes
  authenticated archive digest/CRC, all manifest digests/sizes, clean source
  identity and the actual signatures of all three ABI APKs.
- Windows immutable QA package 414312598 / asset 645287520 is 30,775,474 bytes,
  SHA-256 `fe2d6783bf205a30aa5c6c820e87c3df0da2d0f3768cff4ba4f8900a19092169`.
  Local checks pass published digest, CRC, package identity/version, x64 PE,
  embedded native SDK/helper/public root, and publisher signature verification.
  Only the public envelope was supplied to the running native acceptance job.
  Installed update acceptance is still pending its actual runtime result.
- The second Mac transition has genuinely installed build 79 and acknowledged
  local bootstrap; session restoration is pending a manual macOS Keychain grant.
  This entry does not declare that outstanding real acceptance PASS.

## Windows runtime observation correction (2026-10-15)

- Run 38811398713 reached the actual installed baseline, real voice listener,
  background download and prepared package. Its UI driver then failed before
  consenting to apply: bounded result `history_anchor_missing`, artifact
  12010447817 (authenticated SHA-256
  `ce781211fa5f6cfcbcb7c20aeda4b3eb2edfef5a0307a2d7d811deeec1fa3f5c`).
  No completed Windows update is claimed.
- The measurement mistakenly searched ordinary Text widgets, while shipping
  message bodies use FormattedMessageBody with SelectableText.rich. A widget
  test rendering the actual body reproduced this exact failure before the fix.
  The driver now measures the rendered message body, retaining clipping,
  ordinal and pixel-offset assertions. A second test covers partly visible
  rows and cached offscreen rows. Ready/consent/apply/bootstrap assertions are
  unchanged. Failures after authenticated fixture readiness now also retain
  a rendered image of that owned synthetic fixture, without raw error data.
- The latest ordinary app source 838cd41d has a verified universal macOS ZIP
  (47,400,174 bytes; SHA-256
  `38dde09d23e138dd12fbe05e6f99c3b84ec5584d64f63c5830499b91e11b2e93`)
  and unsigned iOS device Release compile. The current driver-only correction
  does not change their shipping entrypoint or application behavior.

## Windows consent/apply diagnosis remains open (2026-10-15)

- Source 109513ad full CI 38816000280, browser 38816000282 and signed native
  candidates 38815993186 PASS. Final Android ZIP 12011705236, all APK signatures
  and manifest hashes PASS. Windows distribution source 76119c94 is an actual
  merge of master 3e6ac963 and head 109513ad; its complete source tree equals
  that head. Installer/portable/recovery artifacts pass authenticated archive
  verification and the portable manifest's per-file hashes. The stable full
  package also passes its release hash/size, CRC, x64 PE and publisher root.
- The real installed run 38815993370 again failed, this time after history
  measurement and a genuine before-update image. Authenticated artifact
  12012192108 SHA-256
  `b44685f4bc86b8dccd5100f011c75fc28132e15c1482e4d3ad4d71eebe9d1f51`
  contains before/failure images and bounded result `control_missing`.
  Visual inspection confirms voice connected with microphone and incoming
  audio off, Ready banner, scrolled history and the late draft before consent.
  The failure image shows the application's failed-update banner. Neither
  the exact failed control nor installed native build was retained by that
  driver, so this is not enough to name the native cause or accept N-to-N+1.
- The follow-up driver waits for hit-testable controls, lets dialog animations
  settle and verifies the decline dialog actually closed. It records only
  bounded step/build/phase and allowlisted native failure codes, and explicitly
  detects an apply rejection while the original process is alive. No profile,
  draft, message, token, raw exception or local path is added to diagnostics.
- A focused real widget dialog test independently reproduces the old first-match
  selector choosing the covered panel instead of the dialog's identically named
  consent button. The old selector was observed FAIL; the hit-testable selector
  passes. This proves a driver defect, not the still-unknown native failure cause.

## Windows directory-lock regression (2026-10-15)

- Source 36 full CI/native/browser checks PASS, but installed run 38819673574
  fails. Authenticated artifact 12012703013 (136,315 bytes, SHA-256
  `305dd1cd19e1838313e87c2928d4f6359545861ec9ea8d8f0c4aad7908f89380`)
  reports step `text_open`, installed build `78`, failed phase and
  `bootstrap_identity`. This confirms the observed app is still build 78,
  not a successful accepted 79. The published 79 AOT data contains compiled
  release `windows-qa337-r58`, not `r57`; package/resource checks also pass.
- Source inspection identifies a definite directory lock: the owned launcher
  starts the baseline with `cwd=current`, and DesktopRecovery.arm launches
  the external monitor without a working directory override. The monitor
  retains that inherited directory while waiting for replacement. Microsoft
  documents that a running process's current directory cannot be renamed:
  https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setcurrentdirectory
- Added a real Windows monitor regression: launch it from the target directory,
  wait for its actual Ready file, then rename that directory while the monitor
  is alive before the existing failed-apply/real-Flutter-relaunch assertions.
  This specific regression awaits execution before the implementation fix.
- Actual Windows RED confirmed at source e0fef828: native component run
  38823253138 / job 116724611684 fails exactly with
  `Recovery retained a lock on inherited current directory`, after the real
  monitor reached Ready. This is not a mock or a static assertion.
- The fix supplies LOCALAPPDATA as the child's working directory and the
  standalone monitor independently switches to that validated ancestor before
  Ready. All monitor paths remain absolute; the application's own process cwd
  is unchanged. A short ancestor also avoids Windows child-launch limitations
  for a current directory beyond MAX_PATH. The pinned Velopack 1.2.161 manager
  already launches Update.exe from its parent, so it needs no workaround.
- Local recovery retry/baseline tests (3) and focused analyzer PASS. The corrected
  native regression and full installed transition now require a fresh Windows run.
- Installed acceptance now also triggers for native runner/recovery, update
  bootstrap/adapter and packaging changes, not only changes to its UI driver.
  New runs of this gate supersede older runs on the same branch. This closes
  the filter omission that initially left the native working-directory fix
  without a fresh full installed-client transition.
