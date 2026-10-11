# Local feature acceptance: Web, Android, iOS

Scope: FV2-006, dependencies FV2-002/003/004/005. Actual backend/API and server-side ACL remain unchanged.

## Host setup (macOS Apple Silicon)

Installed on this Mac: Colima/Docker (dedicated `boohtacord-qa` profile), OpenJDK 17, Android command-line tools/CLI, iOS 27 Simulator. The Android target uses the official AOSP API 35 ARM64 image; Google Services are not required by this application. Android SDK licences were explicitly accepted by the user.

```sh
brew install colima docker docker-compose openjdk@17
brew install --cask android-commandlinetools
colima start --profile boohtacord-qa --cpu 4 --memory 8 --disk 40 --vm-type vz --mount-type virtiofs
# Review/accept Google's licences before installing Android packages.
JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home sdkmanager --licenses
# Official Android CLI replaces sdkmanager; SDK licences remain required.
android --no-metrics --sdk=/opt/homebrew/share/android-commandlinetools sdk install system-images/android-35/default/arm64-v8a
android --no-metrics --sdk=/opt/homebrew/share/android-commandlinetools sdk install ndk/28.2.13676358
JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home avdmanager create avd -n BOOHTACORD_QA_API35 -k 'system-images;android-35;default;arm64-v8a' --device pixel_7
# Create once; reuse the resulting UUID. List available device/runtime identifiers first.
xcrun simctl list devicetypes
xcrun simctl list runtimes
xcrun simctl create 'BOOHTACORD QA iPhone' com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-0
```

`check.sh` sets the SDK/JDK/QA Docker context for its child processes; no shell-profile edits are needed. Create an Android AVD named `BOOHTACORD_QA…` and an iOS Simulator named `BOOHTACORD QA…`. The runner starts a stopped QA AVD without snapshots, and boots the dedicated iOS target. Runtime checks reject physical phones and unrelated emulators. Android uses temporary loopback reverses for HTTPS (4810) and SFU ICE/TCP (4881), removed after the run. Existing mappings are never overwritten. This enables a scoped emulator media path; it does not establish physical-device UDP/QoE acceptance. Mobile TLS accepts only the exact ephemeral certificate for localhost:4810 inside the integration-test entrypoint.

## Each feature

```sh
./tools/qa/local_features/check.sh --feature voice --feature shell --base origin/master --real-stack
# Complete client unit suites, registered component scenarios and native smoke:
./tools/qa/local_features/check.sh --real-stack --full-unit
```

Every run includes the complete Web/Flutter unit suites for selected platforms and authenticated desktop/mobile Web journeys (1440/393 logical px). Reports are under `.out/local-features/<timestamp>/index.html` with test logs, screenshot hashes and machine-readable status. Registration lives in `features.json`. A source change outside registered coverage fails with `--base`. Add focused behavioural tests and screenshots for each new scenario before changing its implementation. The registry selects existing suites; it is not proof that every state of a new feature is covered.

The Web layer runs Vite/production Vue components, keyboard/axe and responsive checks. `--real-stack` also runs the existing authenticated multi-client lifecycle against isolated PostgreSQL, Go API, Tempo and LiveKit. The portable proxy works with macOS Colima. Flutter captures render actual widgets with controlled fixture state; Android/iOS runtime currently checks real authentication, workspace rendering, profile/audio/admin panels and logout. Extend `integration_test/local_qa_test.dart` (or add feature-specific integration targets) for real channel, DM, upload, voice, capture-picker and reconnect scenarios. Media quality/capacity requires separate evidence; screenshots and emulator results do not close those gates.

The default report remains `REVIEW_REQUIRED` until its images are visually inspected. Missing native/runtime runs are `BLOCKED`; failed commands are `FAIL`. A passing widget capture never counts as a passing device run. No fixture mocks access production and no production account is required.

## Visual review and comparison

Inspect every selected screen at native resolution. Check loading/empty/error/success/disabled states, text clipping, phone portrait/landscape, large text, IME, focus order and touch targets. Store review notes, including defects, alongside the run. Do not approve a reference containing pending spinners or nondeterministic times unless that state is explicitly the subject of the scenario.

```sh
python3 -m tools.qa.local_features.baseline approve --run .out/local-features/RUN --destination .out/local-features/baselines/REVIEW --note 'Reviewed selected screens; observations…'
python3 -m tools.qa.local_features.baseline compare --before .out/local-features/baselines/REVIEW --after .out/local-features/NEXT_RUN --output .out/local-features/comparison
```

Baselines are immutable directories. The comparison gallery shows Before/After and SAME/CHANGED/NEW/MISSING. Hash equality is an exact screenshot check; changed pixels need visual assessment. Do not blindly update references to make a check pass. Native screen-reader/system permission/media-picker and paired receiver checks remain separately named scenarios until tested.

## Validation of the harness

```sh
python3 -m unittest tools.qa.local_features.test_policy tools.qa.local_features.test_baseline tools.qa.local_features.test_stack tools.qa.local_features.test_native tools.qa.local_features.test_doctor tools.qa.local_features.test_process
```

No scheduled task, production deployment or GitHub push is configured by this setup. Use this same checked-out source for feature work and its QA run.
