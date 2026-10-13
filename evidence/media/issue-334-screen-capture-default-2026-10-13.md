# #334: ordinary macOS ScreenCaptureKit default

Scope: T-036 (dependencies T-031/T-032/T-033/T-034/T-022), GitHub #334.
Base: `941ae5c809ae47baef3988f2f11ed30d3e989238`.
Native client version: `1.0.41+76`; native release identity order: 55.

Implementation: the ordinary application requests `screen_capture_kit` without
a build flag. The native macOS version check enables window SCK on macOS 13+;
older systems retain the selected-source legacy path. Explicit `baseline`
keeps the previous routes. Source lookup still fails closed; no window-to-display
substitution, codec/profile/audio changes or new telemetry were introduced.
The existing snapshot exposes the effective engine/source class. Standard
release builds inherit the application default; no special QA target is needed.
Build and rollback instructions: `docs/runbooks/macos-screen-capture-default.md`.

Focused verification:

- Dart selection RED: expected `screen_capture_kit`, observed `baseline`.
- Dart selection, platform defaults, ReplayKit and version regressions: PASS,
  24 tests. `flutter test --no-pub test/screen_scope/native_screen_capture_options_test.dart test/profile_screen_test.dart`.
- Compile-time `baseline` override: PASS, one targeted test with
  `--dart-define=BOOHTACORD_MACOS_CAPTURE_ENGINE=baseline`.
- Native availability/override policy: PASS, four cases executing the production
  inline helper against supported/unsupported availability. This tests policy,
  not an actual older macOS device or capture session.
- `tools/verify/contracts/verify-contracts.ps1`: PASS, 19 parity tests,
  OpenAPI lint and 108-operation parity. API/media contracts are unchanged;
  only native build identity metadata was advanced.
- Ordinary macOS Release build: PASS, pinned Flutter 3.47.5, without a capture
  engine define. Runtime window/display/stop-start acceptance: NOT_RUN at this
  implementation checkpoint; an earlier opt-in build is not proof of this code.
- Signed Android release: pending the standard existing tag-triggered workflow;
  no local release signing identity is available. Do not substitute a debug key.

Original local logs: `.out/qa334-20261014/`. Generated artifacts and screenshots
are ignored and are not staged. Expanded benchmarks, exact 60 FPS, load/device
matrices and epic acceptance are outside this task. #334 remains open until its
specified basic runtime checks are recorded; #326/#330 are not closed by this
default change.
