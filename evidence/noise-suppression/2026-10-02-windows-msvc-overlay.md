# Windows/MSVC RNNoise build gate

```yaml
status: PARTIAL
gate: Flutter Windows Release build with native RNNoise enabled
failed_run: https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/36991122856
failed_revision: 1c2bc0a
root_cause: MSVC rejects C99 variable-length scratch arrays in pinned RNNoise pitch.c and celt_lpc.c
repository_fix: b81128b adds CMake-generated compiler-only overlays that replace only the VLA declarations with stack-allocation calls; pinned upstream source and model remain unchanged
flutter_tests: PASS, 404 local macOS tests; these do not compile the CMake overlay
audio_tool_tests: PASS, 5 Python tests on current origin/master source tree
native_artifact_tests: PASS, 2 Windows overlay SBOM/sidecar tests
windows_release_after_fix: PASS at 52c6320; standalone run 36996236288
cmake_pcm_parity_fixture: PASS; stock and generated overlays produce bit-identical PCM on host
hardware_audio_acceptance: NOT_RUN
release_readiness: NO_GO for physical audio acceptance; hosted distribution gate passed
```

The Flutter Windows CI #14 failure output identified C2057/C2466/C2133 at the
runtime-sized arrays. The replacement overlay is generated only in the CMake
build directory, leaving locked upstream source checksums intact. The workflow
must compile the overlay under MSVC; the optional deterministic PCM fixture
should also be run against both stock and overlay builds on a compiler that
supports VLAs before treating behavior preservation as verified. The fixture
has now passed, including reset/replay, and hosted MSVC compiled and retained
the distribution after public-header and checkout-byte fixes. The complete
[release record](2026-10-02-release.md) binds the actual revision, run, artifact
and checksums. A passing Windows build does not establish microphone quality,
routing, or acoustic acceptance.
