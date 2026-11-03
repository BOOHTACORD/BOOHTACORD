# Issue #177 — macOS audio factory bootstrap

Date: 2026-10-07
Source issue: https://github.com/BOOHTACORD/BOOHTACORD/issues/177

## Checks

- **PASS** `clients/flutter/packages/flutter_webrtc/test/unit/factory_bootstrap_test.dart`
  verifies `initialize → createPeerConnection → event cancel → peerConnectionDispose`,
  and confirms the idempotent second call does not create another connection.
- **PASS** Flutter `test/audio_devices/scan_scope_test.dart` and `test/app_state_test.dart`
  (61 AppState tests).
- **PASS** Flutter analyzer for the changed application files.
- **PASS** `flutter analyze --no-pub` in the local `flutter_webrtc` fork.
- **PASS** macOS debug build: `build/macos/Build/Products/Debug/BOOHTACORD.app`.
- **PASS** Android release build: `build/app/outputs/flutter-apk/app-release.apk` (53.8 MB).

## Physical acceptance

- **PASS** macOS debug build at source SHA `175ed0b9` showed multiple physical
  endpoints in the audio settings before Join: `CORSAIR VOID ELITE Wireless
  Gaming Dongle` and `HyperX Quadcast` as inputs; `Mi Monitor`, `CORSAIR VOID
  ELITE Wireless Gaming Dongle`, `HyperX Quadcast`, and `Динамики Mac mini` as
  outputs.
- **PASS** Selected a non-default input and output before Join, restored the
  system choices, and refreshed the inventory; all endpoints remained visible.
  No Room connection, microphone test, or capture was started.
- **NOT_RUN** USB/Bluetooth hot-plug while the settings screen is open and
  privacy-indicator observation still require a separate physical check.
