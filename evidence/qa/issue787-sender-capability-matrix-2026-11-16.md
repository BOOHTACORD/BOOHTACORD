# Issue #787 sender telemetry capability matrix

This record covers the sender-side, best-effort telemetry relay added for issue #787. The relay carries one bounded envelope with the active publication's lease, media-session ID and generation. It uses the existing reporting cadence, adds no `getStats` polling, does not persist telemetry, and does not affect media or the existing administrator report when it fails.

## Capability matrix

| Client/platform | Capture dimensions | Capture FPS | Encode FPS / bitrate | Packet loss / RTT / quality reason | Current evidence |
|---|---|---|---|---|---|
| Web | Measured from the browser capture track snapshot included in the confirmed publisher descriptor | Configured from the selected screen profile | Measured only when existing sender diagnostics expose fresh values; otherwise `not_exposed`, `unsupported` or `stale` | Packet loss only after a >=9 s sender window; RTT and reason only from fresh sender diagnostics; otherwise availability is explicit | Focused tests and paired Web→Web real-stack at 1440/393 px PASS; evidence in `issue787-paired-web-2026-11-16.md` |
| Flutter Android | `not_exposed` by current sender scope | Configured from selected quality | Measured only when the existing native sender report supplies fresh values | Packet loss only after a >=9 s window; RTT/reason only when supplied by the current report | Focused Dart tests; device and paired-stream acceptance not run |
| Flutter iOS | `not_exposed` by current sender scope | Configured from selected quality | Same capability contract as Android | Same capability contract as Android | Focused Dart tests; iOS runtime and paired-stream acceptance not run |
| Flutter macOS | Measured only when current native descriptor readback contains actual capture dimensions; otherwise `not_exposed` | Configured from selected quality | Measured only when the existing native sender report supplies fresh values | Same freshness/window requirements as Android | Focused Dart tests, physical-Mac Debug sender lifecycle, and macOS → Web selected-stream telemetry pairing PASS; case 18 measured 1280 × 720 and kept configured 60 FPS/1080p60 target distinct; see `issue787-flutter-macos-web-pair-2026-11-16.md` |
| Flutter Windows | `not_exposed` by current sender scope | Configured from selected quality | Measured only when the existing native sender report supplies fresh values | Same freshness/window requirements as Android | Focused Dart tests; paired runtime/device acceptance not run |

`configured_only` values describe requested/configured settings, not observed performance. Missing or unsupported SDK counters remain unavailable; the relay does not synthesize them. A stale sender sample is marked `stale` and its dynamic values are omitted. Packet loss is withheld until the sampled interval is at least nine seconds. Each request is capped at 2 KiB and sent only while the publication descriptor has been confirmed for the active lease/generation.

## Evidence

- Web focused Vitest: `screen_sender_telemetry.spec.ts`, `screen_sender_reporting.spec.ts`, and `screen_profile_metadata/livekit_binding.spec.ts` — PASS (6 tests), including a stalled relay check proving it does not hold the existing admin report cadence.
- Web Vue type check (`vue-tsc --noEmit`) — PASS.
- Flutter focused tests: envelope, authenticated report API, report isolation/cadence, sender runtime binding, and sender payload — PASS (15 tests).
- Targeted `dart analyze` for all changed Flutter source and test files — PASS. Full-project `flutter analyze` reports existing lints elsewhere; all findings in changed files were fixed and the targeted analysis is clean.
- First registered local-feature run: `.out/local-features/20261116-051919/report.json` — FAIL overall. Web unit/build and `screen_share_ui` passed; `screen_profile` had one skipped publisher/viewer test (BLOCKED). Full Flutter unit reported 2002 passed with one skipped test (BLOCKED); component captures passed. Both real-stack viewports and Android integration targets failed before API readiness because this worktree path was outside Colima's mounted roots. A separate reproduction showed Tempo's `/etc/tempo.yaml` bind mount appeared as a directory. iOS runtime was BLOCKED with no registered QA device. Source-stability was PASS for worktree fingerprint `35844cf664399979e1f819c5361dc13c3209a589b7b8394837e8cd02e493089f`.
- Paired browser/native sender-to-viewer telemetry: macOS → Web **PASS** in the follow-up below. Android/iOS/Windows pairing and actual media-quality acceptance remain **NOT_RUN**. The generic Android auth failures above do not constitute sender acceptance.
- Source-resolution visual review of the generated screen-share captures: at 390 px/200% the four-person roster remains inside its panel with wrapped names and no icon overlap; at 1440 px the two-stream switcher uses two equal 16:9 cards with separate “Эфир” and “Смотрим” labels; the mobile diagnostics fixture shows receiver data and one concise sender-unavailable message; at narrow width/200% the viewer controls remain in one row. Flutter screen-share captures preserve their existing mobile/desktop layouts. These fixture screenshots do not prove live media delivery.
- Hardware, network-quality, and capacity claims — NOT_RUN. No media capability or capacity conclusion is drawn from unit tests.

## macOS sender build and lifecycle attempt (2026-11-16)

- `python3 -m unittest tools.qa.macos_sender.test_run -v` — PASS, 3 tests. The first isolated native build exposed a missing repository-relative updater hook in the private source copy; PR #816 fixes the copied root and its regression test.
- `BOOHTACORD_QA_RUN_NAME=qa787-20261116 python3 -m tools.qa.macos_sender.run` — the 41 focused Flutter QA tests and physical macOS Debug build passed. The app bundle SHA-256 was `1d216baad64141c7cef043f7647d6ed2ccd829a410d75c7a3ab399db12cea1de`.
- `BOOHTACORD_QA_RUN_NAME=qa787-20261116 python3 -m tools.qa.macos_sender.observe --work .out/qa787-20261116/owned-tym6l5as --mode healthy --index 1 --hold 60` — harness PASS for owned QA login, API/SFU join, capture source discovery, publish and stop. It emitted three successful existing sender-report completions and stopped with no pending reports/descriptors. This harness case did not include a viewer and does not confirm the separate ephemeral sender-telemetry relay response.
- The receipt remained `waiting_first_frame`; sender collection reported `unsupported` and no actual capture/encode measurements were observed. Computer Use reported the Mac locked, so native visual review and visible presentation were NOT_RUN. The reported harness PASS is limited to app/publish lifecycle.
- `BOOHTACORD_QA_RUN_NAME=qa787-20261116 python3 -m tools.qa.macos_sender.observe --work .out/qa787-20261116/owned-tym6l5as --mode cleanup --index 0` — PASS for deletion of the two known keys in the isolated QA Keychain namespace; the runner then removed its stack/private app resources (`runtime.json`: `PARTIAL`, phase `disposed`, `owned_resources_removed: true`).
- Flutter macOS → production Web viewer pairing, native/system picker acceptance, hardware quality and capacity remain NOT_RUN. No media-quality or capacity claim is made.

The feature registry includes the focused tests and capability-matrix record under `screen_metrics`.

## Colima-shared local-feature run

- The second registered run used worktree source `e2961ce0201518e144c7ad21c49999069533f9d6`, fingerprint `57ab88ab0ff16ef776f7d4a60058be2dc20e0c772a716d53e6953a403c51bb4f`, and report `.out/local-features/20261116-060409/report.json`. `source-stability` was PASS. The runner used `BOOHTACORD_QA_EGRESS_PLATFORM=linux/amd64`: the pinned multi-architecture Egress image's arm64 variant fails before startup because its configured `egress` user is absent, while the same digest's amd64 variant starts. No repository files or QA image pin were changed for this local override.
- Web unit/build, accessibility, and all selected browser feature profiles passed except `web-screen_profile` (BLOCKED, one skipped publisher/viewer test). The 1440 and 393 real-stack viewport profiles both passed. Their logs include decoded server-cached previews, preview refresh, screen-share mini-player return, owner stop, view removal, and track-end lifecycle.
- Full Flutter unit and component capture stages were BLOCKED by one skipped test each; Android runtime, the six selected #689 integrations, and Android update-required passed. iOS runtime was BLOCKED because the dedicated QA iOS device was unavailable. Paired cross-platform sender-to-viewer telemetry remains NOT_RUN.
- `android-runtime-issue786_deafen_test` failed because the viewer-side roster did not show the local user's updated `deafened` state after toggling. The failure was reproduced both on this PR6 source and on a clean worktree at PR5 base `e2961ce0201518e144c7ad21c49999069533f9d6`; this is a pre-existing #786 acceptance failure, not a regression from PR6. It remains recorded as FAIL and is not counted as a telemetry test pass.
- Source-resolution screenshots were opened and reviewed: `images/web-real-stack/1440/screen-share-compact-statistics.png` and `screen-share-listener-participant-cards.png` are 2880×1800 (1440 CSS px at 2×); the corresponding 393 viewport captures are 1179×2556 (393 CSS px at 3×). The desktop stats panel stays within the stage and shows receiver dimensions with FPS explicitly unavailable, configured sender profile, and one sender-measurement-unavailable message. On the phone viewport, the stats sheet fills the width without horizontal overflow, separates receiver and sender cards, and retains large controls. The two-stream desktop switcher uses equal side-by-side cards; the phone stacks cards vertically with the selected stream prominent. These screenshots document UI/layout only and do not prove paired telemetry delivery or hardware media quality.
- The 1440 real-stack report also includes existing Flutter screen captures. Their earlier source-resolution review found the audience roster strip, mini-player, and desktop viewer controls within their bounds; component captures remain BLOCKED because of the skipped test noted above.
- Hardware, paired sender/viewer media-quality, network-quality, and capacity acceptance remain NOT_RUN. No media capability or capacity conclusion is drawn from these tests.
- After this run, only the prose decision records for PR6 in `tools/qa/local_features/features.json` were clarified to reflect the observed report: selected Web/Android profiles passed, skipped profiles and missing iOS hardware remain blocked, and the baseline #786 failure remains separate. The scenario IDs, selection, commands, assertions, implementation, and captures were not changed; `source-stability` applies to the exact candidate used during the recorded run.

## Host runtime availability re-check (2026-11-16)

To choose the next paired Flutter → Web acceptance target, the QA host runtime inventory was checked:

- `flutter devices --machine` listed macOS and Chrome only.
- `adb devices -l` listed no attached Android device.
- `xcrun simctl list devices booted` listed no booted iOS simulator.
- No Windows runtime was available on this macOS host.

This is a device-availability check only. It is not paired telemetry, capture, visual, media-quality, or capacity evidence. The earlier macOS lifecycle attempt did not pair with a viewer and its native visual review was NOT_RUN while the Mac UI was locked; the later paired macOS result is recorded below. Android/iOS/Windows Flutter → Web pairing remains NOT_RUN. No media-quality or capacity gate is promoted by this inventory.

## Flutter macOS → Web paired telemetry follow-up (2026-11-16)

The physical Mac Debug sender and authenticated production Web viewer shared one isolated QA API/SFU stack. Native case 18 and Web receipt `receiver-18.json` both report PASS: the selected native screen decoded; one authenticated realtime event matched the fixed macOS/Flutter sender scope; a fresh selected sender sample appeared; and `Цель: 1080p · 60 FPS` remained distinct from the measured 1280 × 720 sender resolution and configured 60 FPS.

The 1440 × 900 Web screenshot was inspected at source resolution. The video remained visible around the statistics panel, with receiver statistics, sender measurements, and the configured target presented in separate groups without clipping. The screenshot and runtime receipts stay in ignored `.out/qa787-20261116/`; the committed visual observation and limitations are in `issue787-flutter-macos-web-pair-2026-11-16.md`.

The same-host run lasted 110 seconds and used a synthetic native QA window plus a headless browser with the local certificate-error exemption. It proves only the selected-stream telemetry flow. Android/iOS/Windows pairing, native/system capture-picker acceptance, five-minute/two-physical-device presentation, audio fidelity, hardware/network media quality, and capacity remain NOT_RUN. Issue #787 remains open.
