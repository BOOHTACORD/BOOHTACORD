# PR 695: Android local-feature gate on dedicated emulator

2026-11-09. Exact source `c96af5782b34d968fbc43de831cf816840316de5`, clean
tracked diff (SHA-256 of empty diff `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`).
A separately created AOSP Android 35 x86_64 emulator named
`BOOHTACORD_QA_648_CANONICAL` ran the project command for features auth,
connection_status, screen and voice, Android only, base
`8306413a84c224a712509d7a059916c95b00bd3c`, real stack. The source and Linux
Flutter 3.47.7 ran in WSL on this Windows host with an isolated API,
PostgreSQL and LiveKit. An owned localhost-only relay bridged Flutter's VM
service to the Windows ADB forward using local process pipes; it did not
modify firewall or system network configuration. The integration entrypoint
used the project test-only certificate pin and synthetic account.

The final command exited 0 with overall `REVIEW_REQUIRED`: flutter-unit PASS
(1,820 passed, 3 skipped as reported by Flutter), flutter-component-captures
PASS (500 passed), and android-runtime PASS. The runtime result explicitly
covers authentication, authenticated workspace, profile/audio/admin panels
and logout; it says media NOT_RUN and physical_device false. It does not
validate voice rejoin or audibility. `report.json` SHA-256
`fc380a4f7b66fab9e9b335a22da97dcd24b1b3d289e6d0dd70da01933aea6ff5`;
`android-runtime/runtime.json` SHA-256
`0837c05b3166be7489d7339ce1b069ca402d55a83b2c2d8ff02c89fba26c6885`.

All 14 native 1080 x 2400 screenshots were inspected at original resolution:
auth/logout, navigation, favorites, search, status, profile, audio, admin,
support and screen configuration were identifiable; the screen configuration
images show a scrolled modal. No voice connection was depicted. The 174
component screenshots were not individually reviewed, so visual review stays
NOT_RUN and the overall gate is not marked PASS. No screenshot baseline was
approved. The source report records 188 screenshots, 183 unique SHA-256 values.

The first Linux gate attempt had flutter-unit and component tests PASS but its
Android step failed before runtime because a CR from the Windows-created shell
script was appended to the device ID. The script line endings were corrected;
the complete gate above was repeated. Earlier Windows direct invocation had
failed before execution due to the `python3` app alias. The first AVD startup
stalled before ADB, and a fresh launch with software graphics booted. The
temporary app and ADB reverses were absent after the test; the owned relay and
emulator were stopped. The AVD is retained on D: for future work. No production
deployment, physical media or iOS acceptance is claimed.
