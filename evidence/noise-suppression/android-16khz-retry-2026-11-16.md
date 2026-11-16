# Android 16 kHz RNNoise and retry

The API 35 x86_64 QA emulator reproduced the failure in an actual WebRTC
microphone loopback: 16 kHz mono, `unsupported-audio-format`, zero processed
frames and 1531 fallback frames. The same test passed after enabling the
existing bounded 16-to-48 kHz conversion for Android capture only. This is an
emulator processing result, not physical-device acoustic or capacity evidence.

Android JNI instrumentation passed both the existing 48 kHz state test and the
new 16 kHz frame test. Flutter retry and native noise status tests passed (18).
The retry remains honest about unsupported state and does not assert activity.
On the isolated Linux Docker stack, the API 35 emulator also authenticated to
the real API, joined an owned LiveKit room with microphone permission, and
reported 16 kHz RNNoise active with processed frames and no failure. The
registered native scenario, including automatic permission only on the
dedicated QA emulator, passed from a clean application install. Captures and
runtime results are under `.out/wsl-android-rnnoise-sfu3/`; this does not prove
physical microphone quality or a paired listener's experience.

Further emulator runs exposed a separate transient status-read timeout after
RNNoise had processed frames. The previous monitor immediately attempted a
WebRTC fallback, which sometimes failed and muted capture. Diagnostics showed
`TimeoutException` from the native status call. Android now tolerates two
consecutive status timeouts and initiates the existing recovery on the third;
successful reads reset the counter. Other exceptions, reported processor
failures and non-Android platforms retain immediate recovery. Focused tests
passed for these cases. On the isolated API/LiveKit stack the strengthened
Android scenario remained active and processed additional frames over three
seconds; `.out/noise-postci-fixed1/android-rnnoise-active.png` was visually
inspected at 1080x1920. This is not physical speech or acoustic-quality proof.

The focused host C++ processor test also passed. Flutter CI analysis passed with
the repository's `--no-fatal-infos` setting; changed-file analysis passed with
no findings. The registered real-stack run
`.out/local-features/20261116-184242` used a local Linux Docker daemon and
finished FAIL: 2004 Flutter tests passed with 3 skips (unit gate BLOCKED),
696 component captures passed, and eight Android runtime scenarios passed,
including the RNNoise SFU scenario. The Android issue #786 deafen scenario
failed; its identical failure at the same assertion was reproduced separately
on the clean master commit `fa7a41ec3d220b01d3a407e763ac1fe51a489396`.
The run's source stability check passed. A separate diagnostic test on that
baseline showed that a deafen-only change does not alter the canonical roster
encoding used for change detection. This existing defect is independent of the
RNNoise capture changes. The associated server fix uses the v2 public roster
representation for bounded change detection, preserves v1 serialization and
keeps lease proofs private. Focused tests passed for both deafen transitions,
fan-out to subscribers, transport bounds and legacy compatibility; 22 tests
in the two affected Go packages passed without skips.
The Android issue #786 native scenario then passed on the local API and
LiveKit stack, verifying both deafen transitions. Its 1080x1920 capture at
`.out/baseline-deafen-diagnostic/issue786-deafened-v2-roster.png` was
inspected: the participant's red deafened icon and the active red control
are visible and aligned. The capture is from the isolated baseline worktree
with the same server fix; it is not physical-device evidence.
The same native scenario passed again on the combined Android and server
candidate, including both deafen transitions and the screenshot assertion.
The final 1080x1920 capture is
`.out/android-deafen-final/issue786-deafened-v2-roster.png`; visual inspection
confirmed the matching red participant icon and deafen button.
The subsequent full Android run `.out/local-features/20261116-213956` was
interrupted after the test driver stalled on the application splash screen;
its Flutter unit stage was BLOCKED by three skips and component captures passed.
It is not a completed acceptance run.

The Linux native contracts suite passed on an isolated clone whose source
fingerprint matched this worktree: 1781 tests passed with 27 skipped. This is
not a claim that skipped, physical-device, or production-release gates passed.

Visual inspection at source resolution: the 390x480 audio capture shows readable
device controls; at 320x480 with 2x text the title is ellipsized and the long
device notice wraps heavily. The isolated 390x844 Android-theme menu capture
`.out/android-noise-visual/android-noise-retry-menu-390.png` shows readable
white RNNoise text on a dark selected row; the selection is tappable in widget
tests. The source-resolution native SFU capture shows the RNNoise 0.1 selector,
green active status, AEC/AGC toggles and connected voice dock without overlap of
the active status. These captures do not prove a physical-device interface.

Physical phone, acoustic noise reduction, call quality and update installation:
NOT_RUN. A separate debug APK uses application ID `ru.boohtacord.app.noisecheck`,
display name `BOOHTACORD Тест`, and the same audio implementation as the tested
16 kHz candidate; it predates the status-timeout handling above. On the
dedicated API 35 emulator it installed alongside the original
package, opened the sign-in screen, and passed the same 16 kHz loopback test.
It cannot update the release-signed app or share its local session.
