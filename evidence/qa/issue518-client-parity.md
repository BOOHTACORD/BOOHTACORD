# #518 — shared-client parity implementation and release

Task PAR-001; dependencies RP-010, IT-001, SP-001. Base master
`d537e067f7b2278e230e8488c72fb44a19379eb6`.

Implementation: awaited durable delivery with server cursor after successful
application, bounded FIFO/dedup and controlled resync on errors/overflow;
server/auth-scoped memory cursor, ready-only retry reset, jitter and manual UI
retry; scoped/coalesced audience invalidation preserving lease heartbeat and
polling fallback; existing-admin telemetry GET/PATCH panel with consent/HTTPS;
separate fullscreen exit vs stop viewing and existing renderer handoff; current
iOS app-only/broadcast documentation. Support #516 and #499–502 are reused.

The authoritative scenario matrix is the existing feature registry. CI validates
IDs, implementation/test paths and Web/iOS/Android decisions. Runtime PASS
requires separate build/source evidence. No physical media PASS is inferred
from source, component tests or an emulator/simulator.

Verification in progress:

- Initial focused tests failed on missing delivery and telemetry classes (RED).
- Full Flutter tests: PASS, 1586 tests / 1 existing skip before final additions.
- Focused delivery/retry/audience/viewer/telemetry: PASS, 23 tests.
- Web suite: PASS, 1609 tests / 483 files, including 2 bounded-delivery regressions.
- Contract verifier: PASS, 19 tests; OpenAPI 116 public / 4 private operations.
- Spec traceability: PASS, 39 indexed requirements; approved Windows brief
  unavailable on this Mac, so this is committed-index validation only.
- Android actual Go/PostgreSQL replay TEXT/edit/delete/react/pin + reachable
  telemetry: passed in `.out/issue518/android-parity2`; a refresh tap missed its
  hit target, so the strengthened scenario makes missed taps fatal and is rerun.
- Strengthened actual-stack smoke: PASS separately on Android API35 emulator
  and iOS27 QA Simulator, version 1.0.45 (80), missed taps made fatal. Both
  exercised real Go/PostgreSQL/TLS, TEXT edit/delete/react/pin replay, a second
  account DM edit replay, no duplicates, preserved selection, reachable Guild
  telemetry GET/refresh, default local-only mode and logout cursor cleanup.
  The peer fixture explicitly selects the signed-in peer instead of an unrelated
  seeded member; server correctly denied the unrelated pair during test setup.
  Android: `.out/issue518/android-parity-final`, source `5fbbc9f2`, working diff
  `511797acce4784c7f95ffea829cb0cb5b3bf5c503fa18782f51546297e8c81ab`.
  iOS: `.out/issue518/ios-parity3`, source `5fbbc9f2`, working diff
  `710d3da76aeb8e452eb9b953c0cb4eaaa500aca86be88b3db7720acd5181b4a8`.
  Generated images were inspected: ID wraps, consent stays readable, enabling
  remains disabled without consent, refresh is reachable by scrolling, and DM
  displays the peer's updated message. Screenshots are synthetic private QA data.
- Flutter analyzer: PASS with existing informational lints; no errors/warnings.
- CI action-pin/source policy: PASS (36 workflows / 2 local actions), 8 tests.
- Compact telemetry widget at 320×568 / text scale 2: PASS; opening performs
  no writes, refresh clears consent, HTTP blocks enrollment, HTTPS + explicit
  consent permits exactly the intended update.
- iOS release metadata defect reproduced in the first exported IPA: Runner 80,
  extension 1 / missing marketing version. Fixed all extension configurations to
  read Flutter Generated.xcconfig through Version.xcconfig; effective native
  build settings now report CURRENT_PROJECT_VERSION=80 / MARKETING_VERSION=1.0.45.
  Three IPA artifact regressions PASS. The corrected actual signed IPA verifies
  both approved bundle IDs at 1.0.45 (80), SHA-256
  `a7861517184762b7d7fb712d497ed29f8ebe6010c76796569f938a0226d3e99d`;
  codesign --verify --deep --strict PASS. Distribution uses the owner's existing
  ru.boohtacord.app.test variant, two supplied profiles and existing App Group.
  Signing used a disposable private keychain, which was deleted after export;
  the original user keychain search list was restored. No credential is in Git.
- Registered Web viewport suites and actual Go/SFU stack at 1440 and 393: PASS.
  Registered full Flutter, component captures and general native smoke are
  finishing; final release/portal publication receipts follow after merge.
- Release candidates: 1.0.45 (80), release order 59; release receipts pending.

Physical iPhone/Android capture with/without audio, OS stop, background and
rotation, VoiceOver/TalkBack and paired physical media remain NOT_RUN, tracked
by #62/#132/#303. This report does not close those acceptance gates.
Generated screenshots, logs, secrets and artifacts remain outside Git.

Release-version follow-up: the registered Flutter suite caught the existing
profile-version synchronization regression after the 1.0.45/80 manifest bump.
The unconfigured development defaults in app_version.dart were still 1.0.43/78;
release builds already pass the shared explicit Dart identity defines. Defaults
are now synchronized to 1.0.45/80/r59. The focused profile regression passes;
the final Flutter/native run and CI verify the corrected source. The original
red report is retained, not relabeled as a green run.

Final Web parity follow-up: async reaction/pin observers now return their refresh
work to durable delivery; cursor advancement waits for that work, failures force
resync, and a late observer after account reset cannot dispatch into the next
scope. Local UI notifications retain best-effort error presentation. The focused
regression reproduced the premature cursor (RED); Web full suite then passed
1610 tests, with a further late-reset regression passing in the focused suite.
Production Web build passes with the explicit owned QA public origin. A fresh
actual Go/SFU compact journey is recorded separately, preserving the earlier
1440/393 acceptance rather than rewriting its source identity.

The final registered Flutter/native run at d3e94cb5 has empty working diff:
1592 tests plus the existing skip, component captures, Android and iOS smoke all
PASS. `.out/local-features/20261022-113300/report.json` keeps REVIEW_REQUIRED for
its broad 157-image gallery. Focused changed-screen review inspected production
fullscreen and telemetry widgets at portrait/landscape text2, native telemetry,
DM replay, Guild loading-state captures and profile. No wholesale new baseline
was approved and no physical-media gate is claimed.

Ordinary macOS candidate at d3e94cb5: build PASS; universal arm64/x86_64,
ad-hoc signature verified, ZIP 47,507,925 bytes, manifest/checksums generated.
The public immutable native releases and portal are published after merge.

Final scope regression: installation changes also reset the Flutter replay cursor and fence late socket callbacks. The focused account/server/installation test failed before this fix and all 13 realtime tests pass afterward (`.out/issue518/installation-green.log`). Capabilities remain a fixed protocol set per running binary; a rebuilt binary starts with an empty in-memory cursor.

Final-head CI run 39752221171 passed all 26 jobs, including Windows GUI/SFU,
1611 Web tests and Flutter/native gates. Strict master protection then required
merging the concurrently delivered #520 base into the branch; the product merge
tree was already tested, but the updated head receives its own normal CI.
A protected manual canonical-tag preparation job supplies the missing local
push operation for release publication; tests reject forks, non-master events,
stale master, unknown platforms and replacement tags. Existing release source,
signing and immutable publication checks are unchanged.
