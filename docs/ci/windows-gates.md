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
substitute for the Windows native/GUI run.

Combined acceptance retained in `evidence/ci/windows-gates-final-2026-10-20.json`
verifies four evidence ZIPs from native run 39319882366/source 3d22e900, the
source/run/attempt/manifest handoff, real recovery/relaunch, four actual GUI/SFU
cases and all eight capture hashes. Two original captures were visually reviewed.
The four successful after-window sources use the same Windows gate/build recipe.

The frozen baseline contains 15 Windows runs (13 successful); the complete after
window contains 13 native workflows (12 select Windows: four successful and eight
cancelled with red required aggregates; one metadata-only workflow skips Windows).
Nearest-rank successful-completion execution p50/p95 changed from 1520/1611 s to
877/1025 s. Workflow creation to Windows availability, including waits, changed
from 1533/1625 s to 1025/1329 s. These are observed small-sample historical
distributions, not matched-source causal results or a population SLO. Parallel
runner occupancy increased from 1520/1611 s to 1549/1701 s; no runner-cost saving
is claimed. All cancellations remain in the outcome record. Their old ref-wide
root cancellation boundary is addressed separately in PR455. Stable publication,
installed N-to-N+1 promotion and acoustic/physical capacity are outside this gate.
