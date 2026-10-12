# #283 local quick-jump runtime acceptance

The scenarios use a private, disposable PostgreSQL/Go/Caddy/LiveKit stack and the production Vue/Flutter UI. Three synthetic accounts exercise navigation. No successful API responses are fabricated; failure fixtures stop/restart only the owned API, hold actual replies, or change the owned test database to simulate stale DM membership. Container ownership labels are checked before removal. Password inputs are temporary mode0600 files and removed after the run. Screenshots contain synthetic aliases, empty conversations and navigation chrome, never cookies, IDs or DM text.

Reserved ports: HTTPS4830, Tempo4832, Go4833, SFU HTTP4883/TCP4884/UDP4885. They must be free. The root QA stack uses4810/4812/4820/4880/4881/4882 and must not be reused by this scenario. Use Docker context `colima-boohtacord-qa`. Build an independent Web directory, preserving the other workers' dist:

```sh
VITE_PUBLIC_ORIGIN=https://localhost:4830 npm run build -- --outDir ../../.out/qa283-build
```

Run from the repository root:

```sh
python3 -m tools.qa.quickjump.run
```

`QA_WIDTHS=1440` or `QA_WIDTHS=393` restricts the actual browser run. Output is ignored under `.out/qa283-20261012/{width}`. Each JSON row reports its observed scope, failure phase and screenshot hashes. A PARTIAL runtime cannot close the issue: OS notifications, physical keyboard/IME and other released platforms require separate evidence.

Android uses dedicated AVD `BOOHTACORD_QA_283_API35` / emulator5556, an independent Flutter package copy in `/private/tmp/boohtacord-qa283-flutter`, and only reverse tcp4830. Copy the package excluding only the package-root `/build/`, `/.dart_tool/`, iOS/macOS Pods and .symlinks (retain source directories named `build`); run `flutter pub get`. Then:

```sh
python3 -m tools.qa.quickjump.run_native --platform android --device emulator-5556
python3 -m tools.qa.quickjump.run_native --platform ios --device <dedicated-ios-simulator-udid>
```

The native scenario uses actual app widgets and real HTTP, with controlled integration-test key/IME events. It reports actual Android/iOS debug execution and screenshot captures, not physical device, OS reader, release-build or notification permission acceptance. Inspect captures manually at their original resolution before recording visual PASS. Missing native or OS rows stay NOT_RUN.

The iOS run uses a separately assigned booted simulator; it does not install on a physical phone. Run native platforms sequentially because they share the private 4830 stack. Before compilation, the runner captures HEAD, the dirty diff hash and all Flutter app file hashes, and rejects a private package copy whose app source differs. Previous screenshots/reports are archived and a fresh RUNNING receipt is written, so a failed build cannot reuse an old PASS. Native executable hashes are recorded after successful execution.

The specific native acceptance verifies MEMBER versus existing-DM labels, actual authorized DM navigation without the mobile drawer obscuring it, controlled composition/Enter, later Escape/disposal and account switch. The missing-anchor reply-context fixture sends an actual request for a synthetic absent message in an owned empty DM. The server returns 200 with no matching anchor; the client displays unavailable context. Its screenshot verifies the compact Back header and layout only, not successful message-history acceptance. No server behavior is modified to force an assumed 404.

Ctrl/Cmd-K retains the approved existing search launcher, whose initial mode is messages; Channels and people is a separate user-selected tab. Observed launcher/tab navigation is recorded independently from the literal issue interpretation of an automatically selected quick-jump tab, which remains PARTIAL pending clarification. OS notifications, hardware keyboard/IME, Flutter desktop and release builds are outside this run.
