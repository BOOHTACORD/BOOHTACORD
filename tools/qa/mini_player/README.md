# Mini-player actual transport QA (#247)

This fixture runs production clients against its own disposable Go API,
PostgreSQL and LiveKit. Only the source of browser display capture is synthetic:
a 640×360 canvas and a quiet 440 Hz oscillator. The application publishes and
subscribes through its real admission, secure sessions, UI and SFU. API responses,
room connections and SDK subscription events are never replaced with successes.

## Isolation and prerequisites

Use a clean, dedicated QA worktree. Build the Web client with its ordinary Vite
production build, directing output to `.out/qa247-build`. The fixture imports the
existing repository dependencies and needs the configured Colima QA Docker
context, Playwright Chromium, Flutter, Android SDK and Xcode for native runs.
Android SDK licenses must already be accepted by the operator.

Own ports: HTTPS 4830, Tempo 4832, API 4833; LiveKit HTTP 4883, TCP 4884,
UDP 4885. None of these may be occupied by another case. Local services bind only
to loopback, use disposable credentials and tmpfs database/storage, and are
removed by their unique QA owner label. Credentials remain in ignored temporary
files and must never be copied into evidence or logs.

Android assigned device: `emulator-5558`. iOS assigned simulator:
`57E6A791-8975-4C84-82E6-47321F22C9B8`. Device verification must match the explicit
platform. Coordinate native build slots and memory with other parallel cases.
Do not terminate foreign processes or modify another device's port reverses.

## Run

From the QA repository root, run `python3 -m unittest tools.qa.mini_player.test_native`
for receipt integrity and `node tools/qa/mini_player/layout_test.mjs` for the
production CSS regression. These checks supplement media acceptance.

Remove `/private/tmp/qa247-release`, then run
`QA_HOLD_FOR_NATIVE=1 python3 -m tools.qa.mini_player.run`. It starts and owns all
services, runs actual Web navigation/subscription/cleanup checks, and then keeps
its real publisher available for native receivers. The current Web result is
under `.out/qa247-20261012/web/results.json`.

Run `python3 -m tools.qa.mini_player.native --platform android --device emulator-5558`,
then run it with `--platform ios --device 57E6A791-8975-4C84-82E6-47321F22C9B8`
when the simulator and compilation slot are available. Native source is copied to
`/private/tmp/boohtacord-qa247-flutter`; build outputs remain private and cannot
race the shared Flutter checkout. Rsync exclusions must be anchored (`/build`),
because production source also contains nested folders named `build`.

The runner verifies a manifest of every copied `lib` file, records actual Flutter
versions and executable SHA-256, and archives older reports/screenshots before
writing a fresh RUNNING receipt. Failed/missing scenarios and incomplete required
rows exit unsuccessfully. Original PNGs are ignored artifacts; inspect them at
original resolution. Native 393/320 layout checks explicitly override Flutter
engine viewport metrics and are not physical-device geometry evidence.

The authenticated localhost:4834 HTTP bridge controls removal/republication by sending an owned command file
to the waiting Web fixture. The fixture clicks actual publisher UI controls and
acknowledges completion. No production server or media transport control is mocked.

After both native runs, create `/private/tmp/qa247-release` and wait for the Web
runner to remove its resources. Native owned port reverses are removed in its
finally block. Remove the private Flutter build and owned emulator/simulator when
no longer needed; preserve only sanitized JSON evidence and ignored original PNGs.
An incomplete platform/check remains NOT_RUN, BLOCKED or FAIL and cannot close #247.

The native screenshot driver stores images only. Native source control uses a per-run secret over owned loopback port4834, bounded end-to-end at50 seconds; the holder acknowledges completed production publisher UI transitions atomically. Each run records handler SHA, and refuses a holder launched from different code. Device mutations require the assigned5558/AVD278 or57/QA278 simulator identity.

Repeated fixture registration attempts consume the real server rate limit even for an existing fixed account. If an owned disposable stack returns429, release and replace that stack before the next attempt; never disable the server limiter. Native runs require the browser scenario to finishPASS and enter publisher hold.
