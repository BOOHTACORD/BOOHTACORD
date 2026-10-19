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

The Dart driver requires all 34 existing capture filenames, bounded PNG headers,
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

## Repeatable native shadow comparison

`flutter-ci-shadow.yaml` is a read-only manual workflow. Three serial samples of
the original job run alongside three serial samples of the split reusable gate.
Both arms use the same exact app source, SDK selection and run attempt. The
legacy control executes hash-verified `native/flutter.py` and Android builder
source from `f1b19038`, plus the unchanged two-mode Kotlin script. Its workflow
template is independently bound to that original workflow's SHA256. It preserves
the original Dart/vendor/analyze commands, their order, all visual uploads, both
Kotlin modes, debug pub/plugin regeneration, actual APK inspection and APK upload.
Only the finite measurement wrappers, unique artifact names and public execution
proof are added. Control phases execute real processes; unit-boundary mocks are
not runtime samples.

The comparison requires all 13 actual hosted job identities and nine bounded
current-source/run/attempt/namespace artifacts. It rejects incomplete, failed,
cancelled, foreign, duplicated or unmeasured samples and verifies that the two
new profiles use different runner VMs. Critical time includes SDK setup, uploads,
internal waiting and the final Flutter aggregate. Runner-minutes sum actual job
occupancy, with Dart and Android distributions also reported separately. The
external comparison job is measurement overhead, not part of the production gate.
The legacy control includes finite hash/source-check instrumentation; these are
descriptive same-run observations, not a general hardware or billing claim.
With three samples, p50 is the median and nearest-rank p95 is the maximum.
`NO_GAIN` is retained and fails the comparison if either new critical percentile
is not lower. A failed real test is never discarded or retried into success.

The first hosted diagnostic is recorded separately in
`evidence/ci/flutter-profile-diagnostic-2026-10-19.json`. It proved the two profile
jobs, aggregate and actual uploaded APK/manifest/checksums. Auditing its archive
found 34 PNGs although the initial mandatory subset contained 28; a focused test
then added the six text/DM conversation captures to the mandatory inventory.
The corrected candidate requires a fresh run. All 34 old/new uploaded PNGs were
compared: 32 are byte-identical, while the two Media views only changed their
displayed refresh time. Those four old/new Media files were visually inspected;
no new screenshot baseline was approved. This first diagnostic is not comparative
performance or final-source acceptance.
