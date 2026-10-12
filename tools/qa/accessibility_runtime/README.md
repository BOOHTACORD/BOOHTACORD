# Issue 301 actual accessibility runtime

This harness uses a disposable PostgreSQL tmpfs, the actual Go secure-cookie API,
Caddy HTTPS and LiveKit. It does not mock successful API calls or media transport.
Only synthetic accounts, channel labels and empty conversations are used. Private
credentials stay in mode-0600 ignored inputs and compiled QA builds, never in
published evidence.

Owned ports: HTTPS 4930, Tempo 4932, API 4933, LiveKit management 4983,
RTC TCP 4984 and UDP 4985. The focused Vue browser fixture uses 4937.
Docker resources carry the exact per-run owner label and qa301 prefix.

Run from the repository root with the prepared local Docker context and a free
assigned Flutter SDK lease. `python3 -m tools.qa.accessibility_runtime.serve`
starts and seeds the actual API fixture; its old Web binary is explicitly scoped
to login/API seeding, not acceptance. It waits for `/private/tmp/qa301-release`;
remove that marker before starting a fresh fixture. The active input path is
ignored. Refresh the shared Web dist from the final application source before
`QA_EXISTING_FIXTURE=1 python3 -m tools.qa.accessibility_runtime.run`. That runner
cleans only its own dist copy, records the observed mutable source separately from
the dist manifest, verifies the exact frozen root build-source→dist provenance link, and reuses the
held fixture without creating duplicate accounts. The original stack-creating
mode is `python3 -m tools.qa.accessibility_runtime.run`.

The assigned Android device is emulator-5558 / BOOHTACORD_QA_278_API35; iOS is
57E6A791-8975-4C84-82E6-47321F22C9B8 / BOOHTACORD QA278 iPhone. Native runs reject
other devices before modifying reverse ports. `python3 -m
tools.qa.accessibility_runtime.native --platform android --device emulator-5558`
uses an isolated `/private/tmp/boohtacord-qa301-flutter` copy. Request a serialized
Flutter SDK build lease before native preflight/build. iOS uses the same command
with its platform/device. The actual production lifecycle is initialized before
rendering the QA app. No native media retry is attempted on iOS after the existing
same-device AURemoteIO SIGABRT evidence; stream setup remains NOT_RUN there. Prejoin uses the production state.selectChannel controller with the actual ACL-loaded channel and inspects the real rendered app; it does not claim native channel-row pointer navigation, which intentionally autojoins. Only Android subsequently activates the actual listener join UI.

The held-fixture Web path first checks twelve actual binary geometry cases at
320/393 and normal/rem-text2x, then twenty real connected-voice TEXT/DM/members/search geometry rows (including keyboard-operated scope-select text, heading and filter-row bounds), sixteen axe rendered states and eight keyboard
flows including the connected-voice drawer. `text_scale.mjs` has a separate
QA_SOURCE_CSS=1 focused diagnostic mode for RED/GREEN before rebuilding; this
mode appends authored production CSS to the pinned older binary and is never used
for final binary acceptance. Rem font resize is not browser/OS zoom. On fixture
reuse, actual secure own-session revoke-others cleans only previous synthetic
account sessions; normal UI leave releases the actual SFU lease at completion.

Each attempt archives its previous receipt and PNGs, writes RUNNING before work,
and requires all applicable completed scenario rows. Missing rows or a stale PASS
cannot complete acceptance. Native and Web receipts identify source, executable
or dist, QA handler/target/driver and screenshots by SHA-256. Native screenshot
callbacks store images only. Engine text scale 2 is explicitly an engine override,
not a physical device setting. Emulators/simulators are never called physical.

Semantics and axe are separate from actual spoken-reader testing. TalkBack package
availability is recorded; absent packages yield NOT_RUN. An actual macOS VoiceOver
smoke requires foreground ownership and reading the reader's own announcement
output. Physical mobile VoiceOver/TalkBack and missing OS coverage stay NOT_RUN.
Counts of controls below 24/44 pixels are measurements, not automatic conformance
failures: applicable WCAG exceptions and physical targets require a separate review.
Issue 301 remains PARTIAL while any agreed reader/rendered-state coverage is absent.

Focused checks: `python3 -m unittest tools.qa.accessibility_runtime.test_native`
and `node clients/web/node_modules/@playwright/test/cli.js test -c
tools/qa/accessibility_runtime/playwright.config.cjs`. The latter mounts production
history components and covers empty, populated/date and pagination rows, axe,
named action children and keyboard focus. Five compact participant-status states also require a valid named image role and decorative SVG exclusion.

Finally release only this fixture, remove only its ADB reverses, uninstall the QA
package on assigned devices, shut down only owned emulators, and remove private
builds/inputs/raw logs. Preserve sanitized receipts and ignored original screenshots.
No source staging, Git publication or issue closure is performed by this harness.
