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
