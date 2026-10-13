# macOS capture boundary tests

This harness compiles the actual vendored `FlutterScreenCaptureKitCapturer.m`
against the pinned macOS WebRTC framework. It supplies synthetic CoreMedia
samples and selection records without requesting permission or capturing a
window/display. It tests exact selection, callback stream identity, stopped
callbacks, frame status, timestamps and pixel-buffer lifetime.

```sh
python3 tools/qa/native_capture_boundary/run.py \
  --framework-dir /path/to/WebRTC.xcframework/macos-arm64_x86_64 \
  --out .out/native-capture-boundary
```

The framework directory must contain `WebRTC.framework` from the vendored
package's pinned `Package.swift` dependency. The report records its binary hash
and the native/test source hashes. `RED` returns exit status 1, compilation or
execution without case results returns 2, and all passing cases return 0.

The private `stream` identity is assigned using KVC. This bypasses startup and
is deliberately limited: it does not prove first-frame readiness, async-start
cancellation, permissions, physical source identity, audio, frame cadence,
queue age, scaling performance or resource cleanup under OS capture. Those
remain actual-device acceptance checks. No frame pixels or source titles/IDs
are included in the report; the display identifiers in the test are synthetic.

The optional processor suite compiles the actual resolution processor with a
controlled conversion-helper spy. It tests the no-op path, portrait/odd-source
geometry, preservation of rotation/PTS, the native-buffer fast-path requirement
and injected conversion failure. It does not prove processing performance.
Flutter headers are read; no Flutter build runs.
The processor suite additionally uses real WebRTC I420 scaling and verifies
pool exhaustion/reuse; these are functional controls, not a throughput result.

```sh
python3 tools/qa/native_capture_boundary/run.py --suite processor \
  --framework-dir /path/to/WebRTC.xcframework/macos-arm64_x86_64 \
  --flutter-framework-dir /path/to/FlutterMacOS.xcframework/macos-arm64_x86_64 \
  --out .out/native-capture-processor
```

The diagnostics suite tests bounded aggregates, generations and confirmation.
The lifecycle suite executes readiness/cancellation and bounded video routing
with synthetic stream acknowledgments and an audio-routing spy. Its injected
continuous clock verifies that a queued frame ages across a suspended gap;
it does not prove physical sleep/wake or decoded audio.

The startup suite requires the same framework/header arguments as the processor
suite. It executes the actual DesktopCapturer/SCK startup failure callbacks for
video with and without audio. Injected enumeration failure must remove the
unreturned track's stop handler and release its RTC source. Factory, audio owner
and FlutterError are fakes; legacy RTC window/audio-only failure, OS startup,
permissions and resource return after actual capture remain device checks.
