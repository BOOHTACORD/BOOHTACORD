# Apple native acceptance for #704 — 2026-11-13

Overall gate: **BLOCKED; keep #704 open**. This record supplies scoped native results for #689, not a complete migration or release approval. The machine-readable case-by-case matrix, source/file hashes and screenshot observations are in `issue704-apple-native-2026-11-13.json` beside this file. Raw logs, debug artifacts and images stay in ignored `.out/issue704` and `.out/local-features/20261113-141332`; no generated media or credentials are committed.

## Sources and environment

Updated clean local master from remote to `d9c81545792762859c113ae558df0ddd2609c818`. The Apple package fix is `1d242e562e0171f66e6fa20d2c853f17b52049bf`. Private QA checkout `5be06717f43bd24c842561ded33fee18651610fa` is the same fix cherry-picked onto that base. Subsequent integration fixture changes are pinned by SHA-256 in the JSON; they change test synchronization and capture, not product Dart behavior.

Host: arm64 MacBook Pro, macOS 27.2.1 (26B131), Xcode 27.2 (27B52), Flutter 3.47.7 / Dart 3.13.5. Native targets: dedicated iPhone 18 Pro simulator with iOS 27.0; connected physical iPhone 17 with iOS 27.2 (24B119) and Developer Mode enabled. QA version 1.0.54 (90).

The private macOS/physical iOS build uses bundle `ru.boohtacord.issue704qa`, separate from the installed distribution app. Its iOS entitlements omit APNs and app groups to permit local development signing. macOS QA is ad-hoc signed; physical iOS QA is development signed. `codesign --verify --deep --strict` passed. These signatures do not prove distribution, notarization, APNs or production installation. Full local bundle-file manifests are hashed in the JSON. Simulator artifacts were overwritten between targets; no claim is made that a single final binary hash identifies all earlier target binaries.

The macOS real-stack fixture adds the normal `window_manager.ensureInitialized` / `waitUntilReadyToShow` bootstrap, uses alternate loopback ports, and omits unsupported macOS `IntegrationTestWidgetsFlutterBinding.takeScreenshot` calls. Two native window captures were taken separately. These private fixture overlays and their hashes remain in `.out/issue704/macos-realstack*/runtime.json`; they are explicitly not the untouched registered mobile runner.

## Blocking defects and focused repairs

The baseline Apple app crashed at startup in `RnnoiseCaptureProcessor::Reset` calling an unresolved `supported()` symbol. SwiftPM omitted `noise_engine_names.cc` and `deepfilter/capture_hook/process.cc`; the executable also had unresolved `NoiseEngineName`, `ParseNoiseEngine` and `ProcessDeepFilter` symbols. The permissive application link did not catch this. A real downstream SwiftPM C++ executable probe failed to link before the fix and linked/executed after adding both sources. This probe now runs before the existing macOS vendor tests in the release/CI gate. Synthetic silence only; it proves no audio quality or DeepFilter model capability.

Native listener teardown previously disposed the API while the post-logout guest WebSocket handshake was pending (`Connection attempt cancelled`). The existing integration test reproduced this failure. It now waits for the guest socket to be open and maintenance known, and also captures the recovered listener on iOS. The iOS repeat passed.

The common native smoke read `state.topology` immediately after creating a category. Under WebSocket initial/replay synchronization this could still be the old snapshot and `firstWhere` failed. The owned-stack run reproduced the failure. It now waits for realtime readiness, reads the category from the authoritative admin API to seed the channel, and waits for the channel to reach app state. It also waits for guest maintenance after logout. The repeat completed the whole smoke successfully.

## Native results

- PASS: two previously skipped macOS updater recovery refusal/re-arm tests, zero skips.
- PASS: eight actual macOS vendor capture-option tests and strict Apple link/PCM probe.
- PASS: four native loopback WebSocket cases on macOS and the physical iPhone: silent heartbeat recovery, malformed envelope recovery, synthetic queue revocation, duplicate dispatch. Synthetic session identity and queue size two; no server ACL/load/network/media claim.
- PASS: iOS Simulator owned-stack roster, stale topology history fencing, required-update catalog gate, listener reconnect, and full auth/workspace/profile/audio/admin/favorites/logout smoke.
- PASS: macOS owned-stack empty roster reconnect and populated LiveKit listener reconnect. This listener has no microphone; room connection and roster consistency do not establish audible remote media.
- PASS: 14 migration guard tests, 24 final Python harness tests, no-SSE guard, committed-index spec traceability. Original Windows product brief unavailable on this Mac.
- BLOCKED: full Flutter unit stage — 1,933 passed, one opt-in native trace-export case skipped. The separate two updater tests did run on macOS; they are not that remaining skip.
- PASS (component execution only): 642 selected capture tests, zero skips. Their entire image set has not been reviewed; no component-to-native acceptance substitution.

The canonical `check.sh --real-stack` report remains **FAIL**. Earlier native stages lacked Docker buildx; later listener teardown failed; generated untracked iOS SwiftPM locks changed its source fingerprint, so source stability is **BLOCKED**. The generated locks are retained under ignored output, not silently committed as a dependency update. Supplemental successful repeats do not rewrite or upgrade this report. An early repeat also collided with an owned stack's ports; subsequent standard native targets were run sequentially.

The macOS visual checkpoint run remains **FAIL**: external accessibility inspection activated a SemanticsHandle during a Flutter test. Both checkpoint images were inspected, but that run cannot count as an automated PASS. The separate automated run with no UI inspection passed both cases without suppressing exceptions. An earlier fixture omitted normal window initialization; that failure is retained as well.

## Visual observations

Reviewed native PNGs at source resolution (macOS 2880×1800; iOS 1206×2622). Empty roster has no phantom participant. Populated listener, room highlight, mute icon, member indication and connected one-participant dock agree after reconnect. Unknown-maintenance banner is readable and version remains visible. The old Android-prefixed roster filenames are actual iOS captures in this run.

Reviewed all 14 final iOS smoke images. Auth/logout, channel list/favorites, empty context search, profile, audio/basic/advanced and administration controls fit the tested portrait viewport; longer settings content is scrollable. The support consent warning is readable, but its empty-chat hint sits flush against the left edge. In the text-mode share-setup capture the fixed footer partially occludes the lower content-mode chips at that scroll position; the motion-mode capture shows the full chips and explanatory block. Record these as **REVIEW_REQUIRED** visual concerns; no screenshot baseline was approved and no unrelated UI repair is included. The connection-status screenshot deliberately injects `VoicePhase.error` in the fixture and does not prove a real media outage.

## Reproduction commands

Use pinned Flutter on PATH, Python 3.12 environment, Xcode selected, Docker context `colima-boohtacord-qa`, `BOOHTACORD_QA_EGRESS_PLATFORM=linux/amd64`, and both `NO_PROXY`/`no_proxy=localhost,127.0.0.1,::1`. Docker buildx must be discoverable. All services are disposable local fixtures, not production.

```sh
python -m tools.verify.apple_audio_link.check --output .out/issue704/apple-audio-green
python -m unittest tools.verify.macos_unit.test_run tools.verify.macos_unit.test_events tools.qa.local_features.test_native tools.qa.local_features.test_selection
python -m tools.verify.macos_unit.run
# In clients/flutter:
flutter test test/updates/desktop/recovery_retry_test.dart
# From repository root:
./tools/qa/local_features/check.sh --feature auth --feature connection_status --feature voice --feature update_required --feature chat --feature screen --feature support --platform ios --native-device ios:<dedicated-QA-simulator> --base d9c81545792762859c113ae558df0ddd2609c818 --real-stack
python -m tools.qa.local_features.native --platform ios --device <dedicated-QA-simulator> --target integration_test/issue689_listener_test.dart --output .out/issue704/ios-listener-final
python -m tools.qa.local_features.native --platform ios --device <dedicated-QA-simulator> --target integration_test/local_qa_test.dart --output .out/issue704/ios-smoke-final
```

The ignored private aggregator imports `issue689_heartbeat_test.dart`, `issue689_envelope_test.dart`, `issue689_delivery_revocation_test.dart` and calls their `main()` functions. Those three imported files match the main checkout byte-for-byte. It was run in the private QA checkout with:

```sh
flutter drive --driver test_driver/local_qa.dart --target integration_test/issue704_loopback_test.dart -d macos
flutter drive --driver test_driver/local_qa.dart --target integration_test/issue704_loopback_test.dart -d <connected-physical-iPhone>
```

The macOS real-stack aggregator imports the registered roster/listener targets with the bootstrap described above. Its local launcher is `.out/issue704/run-macos-realstack-automated.py` (hash in JSON), using an ephemeral pinned TLS/credential defines file removed at teardown. The two signed QA bundles remain local; do not distribute test artifacts containing disposable fixture defines.

## Gates still open

The JSON enumerates every requested WS/VR/CF/SEC/CUT case and its missing subcases. Remaining work includes real two-account ACL/session revocation and account switching, restart/outage/replay/barrier/quota/server-pressure matrices, native privacy/leak audit, physical background/foreground/sleep/network switching with a paired audible receiver, APNs-enabled provisioning/sender, and signed distribution install/rollback/observability. Physical iPhone availability alone does not satisfy these conditions. Keep #704, parent #689 and physical audio gate #655 open.
