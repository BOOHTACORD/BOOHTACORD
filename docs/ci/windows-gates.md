# Windows gate (#391)

The reusable workflow keeps its stable `windows / windows` status. Its required
work is now split across hosted runners:

| Job | Required work |
| --- | --- |
| `windows-native-unit` | Standalone VC++ static-runtime recovery compile/dependency inspection and invalid-plan rejection; existing pinned Velopack preflight; complete app/vendor Flutter tests and analysis; GitHub publisher contract tests |
| `windows-build` | One release-mode Windows CI build, native runtime/import checks, measured signing metadata, complete native manifest/checksums, Velopack installer/full package and source-bound payload binding |
| `windows-gui-sfu` | Download exact execution artifacts, verify full payload, real native recovery and Flutter relaunch, then actual GUI/SFU layout/Escape/traversal acceptance on the same executable; verify payload again |
| `windows` | Always run; require every successful job and exact-source/run/attempt GUI/recovery receipt |

Native tests and build run independently. GUI follows build and needs no Flutter
SDK or recompilation. Windows-specific coverage remains on Windows: no test was
removed or moved to Linux on an assumption of platform equivalence. GUI still
uses the original real PostgreSQL/API/LiveKit fixture, actual Win32 input and
synthetic captures. No mock or widget-only replacement was introduced.

## One package for both process journeys

Previously GUI acceptance rebuilt a second executable with a separate driver
entrypoint, after testing recovery against the ordinary build. CI now builds
that QA entrypoint once using `tools.build.windows.run --ci-acceptance`. Without
the driver flag it calls the unchanged production `main()` for recovery/relaunch.
Only its GUI child receives `BOOHTACORD_WINDOWS_GUI_ACCEPTANCE=1`, and the driver
also requires GitHub Actions and a disposable hosted runner. Its existing owned
fixture/path restrictions remain mandatory.

The package includes a hashed `ci-purpose.json` explicitly declaring
`windows-ci-acceptance` and `stable_release:false`. This is a CI acceptance
package containing test instrumentation, not the stable-distribution artifact.
Stable release scripts still use the ordinary build command and production
entrypoint; no release signing, public asset names or updater promotion rules
change. Passing this CI fixture does not certify a separately published stable
binary or installer installation journey.

The existing full release directory and installer artifacts retain their names,
SHA/run/attempt suffixes and 30-day retention. A separate `windows-transfer`
artifact binds every native and installer file by SHA256 and byte count, plus
native manifest, checksums, contracts, approved SDKs and client version/build.
Consumers reject missing/added/changed files, links, case aliases, foreign
source or retry, dirty build and wrong purpose. Inventory limits are 10,000
files and 2 GB per directory; manifests are bounded to 4 MB. Artifacts stay
inside one workflow execution; no mutable latest-build lookup is used.

The GUI result records the tested manifest digest. A failed/absent GUI, failed
recovery, failed runner, incomplete handoff or skipped dependency makes the
stable aggregate fail. Existing recovery/synthetic capture reports remain
retained, and the compact mandatory acceptance receipt is uploaded separately.

Local basic checks:

```sh
python3 -m unittest tools.ci.windows_gates.test_transfer tools.ci.windows_gates.test_workflow tools.ci.windows_gates.test_acceptance tools.qa.screen_setup.test_windows
```

Actual CI acceptance requires hosted Windows: build, seal, transfer and verify
using the commands in `flutter-windows.yaml`, then
`python -m tools.ci.windows_gates.acceptance`. There is no claimed local macOS
substitute for the Windows native/GUI run. Repeated before/after p50/p95 and
failure-rate acceptance remain NOT_RUN, deferred to combined epic validation per
owner. The historical single ~25:20 run is not a percentile distribution.
