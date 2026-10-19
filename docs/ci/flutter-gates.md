# Dart and Android gates (#390, CICD-06)

The existing `flutter` selector invokes `ci-flutter.yaml`. Its independent hosted
Ubuntu jobs are `dart` and `android`; the stable `flutter / flutter` check always
waits for both. `ci-required` still validates the reusable workflow's complete
result, including the aggregate. Neither child is optional. Android release
signing retains its dependency on the same complete reusable gate.

The versioned component map is unchanged. Flutter/app/vendor/native builder,
shared RNNoise, contracts, CI/verification and toolchain changes require both
children. Unknown ownership or unavailable diffs conservatively require both.
Proven backend-only, Web-only and documentation-only diffs skip the entire
Flutter workflow, including Android packaging. No second path filter can
contradict the shared selector.

`dart` preserves public-header regression, locked app dependency resolution, all
application tests, both vendor lock preparations and test suites, recursively
analyzed LiveKit example lock, and the existing full application analysis flags.
The local `python3 -m tools.ci.native.flutter` uses the same implementation.
`android` resolves the app lock once in its own fresh workspace, runs the unchanged
legacy-KGP and AGP built-in Kotlin checks, then builds the actual inspected debug
APK. `--debug --no-pub` reuses that job's preparation. Release builds cannot use
this option: their existing plugin regeneration and signing behavior is retained.

Each child installs and verifies Flutter 3.47.7, Dart 3.13.5 and the reviewed
framework revision. Android also explicitly selects and verifies Java. Only the
existing versioned public SDK cache is reused; pub dependencies remain uncached
and private to each job. No Flutter build output, APK or capture is cached or
transferred as a dependency of the other child.

The Dart driver requires all 28 existing capture filenames, bounded PNG headers,
nonempty measured files and SHA256 values. The original navigation capture and
UI/UX review set remain mandatory uploads. Android requires the actual debug APK,
the builder's source-bound application/signing manifest and exact measured
checksum list. The debug builder still runs `apksigner`, application/version/ABI
inspection and APK size analysis. An absent capture, missing APK, source change,
failed command, failed upload or cancelled child cannot pass the aggregate.

Small execution parts bind the exact tracked source, run, attempt, namespace,
Flutter/Dart/framework identity, ordered completed operations, elapsed driver time
and measured artifact inventory. Artifact names repeat the same execution identity.
The aggregate downloads exactly two parts and rejects extra, partial, duplicate,
foreign, stale or unsuccessful evidence. A full workflow rerun is required; a new
attempt cannot borrow results from an older attempt. Artifacts retain the existing
30-day policy. Failure is written before native execution so a stale PASS cannot
survive a command failure.

These captures are Flutter widget renders, not emulator or physical-device proof.
Device acceptance in #62 remains separate: installation and real cookie/ACL flow,
microphone and audio routing, real background/foreground lifecycle, Android
MediaProjection screen sharing, permissions, connectivity changes and media
interoperability require actual device evidence. CI compilation, APK metadata or
widget PNGs cannot establish these capabilities or close that device gate.

## Acceptance still required

The local focused fault tests and workflow policy validate the graph and failure
semantics. The change is not accepted until actual hosted Dart and Android jobs,
artifact retrieval/source verification, current required status, release-mode
guards and master integration succeed. Compare measured Dart and Android job
durations, whole critical path, p50/p95 and runner-minutes with the retained
monolithic baseline; report sample counts, setup/upload overhead, source revisions
and runner type. Local command mocks do not provide those measurements. Do not
claim a latency or runner-cost reduction from splitting a YAML job alone.
