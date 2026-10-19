# Auxiliary toolchain audit and local setup (#392)

Runtime versions remain in `tools/toolchains.json` / `.node-version` / Go's module
and the reviewed Flutter framework commit. Verification/package SDK selections
are in `tools/ci/toolchains/auxiliary.json`. They do not change server image inputs.
`task check:toolchains` checks both policies and the native input inventory. Install
`tools/requirements-ci.txt` into a local virtualenv before this check.

| Input | Reviewed selection and enforcement |
| --- | --- |
| Python | Linux 3.12.15; Windows/macOS 3.12.10. Exact setup-python expression, actual interpreter check, no pip cache. |
| Java | Temurin setup/cache label 17.0.20+1; observed `java.runtime.version` **17.0.20.1+1**. Both are explicit pins; the runtime must match the complete observed value before Android commands. |
| .NET | SDK 8.0.426; exact setup and CLI check. Root `global.json` disables roll-forward, so a newer preinstalled SDK cannot take precedence. |
| Gradle | 9.3.1 all distribution; official `distributionSha256Sum` checked by the wrapper on download. |
| Android app build plugins | AGP 9.1.0 and Kotlin 2.4.0, recorded in reviewed native input hashes. |
| Flutter Android defaults | Framework `abaf9c523780a608bd46686fd5e53740a07077f8` selects compile/target SDK 36 and NDK 28.2.13676358. The app still derives these from that exact Flutter source. No Gradle/Android SDK directory cache added. |
| Vendor Pub tests | Reviewed locks for livekit_client, flutter_webrtc and the recursively analyzed livekit_example project; the manifest binds all three pubspecs/locks. Original recursive `pub get --enforce-lockfile`, root vendor tests and full app analysis are preserved. App lock is unchanged. |
| Playwright | `@playwright/test` 1.63.0 and browser revision selected by npm lock. Always `install --with-deps chromium`; no browser cache. |
| Windows packaging | vpk 1.2.161 installed/checked by the existing packager; Velopack C SDK has its existing SHA256. |
| macOS SDKs | Existing Sparkle 2.10.0 archive SHA256; WebRTC m150/r2 Pod archive SHA256 plus exact source/depot/patch recipe. No new native binary cache. |
| Other WebRTC targets | Android/iOS SDK 150.7871.01; Android audioswitch full Git revision; Windows/libwebrtc version/URL recorded by the inventory. Existing binary download behavior is preserved, without introducing a native binary cache or claiming a new archive attestation. |

The immutable [Python availability observation](../../evidence/ci/auxiliary-sdk-availability-2026-10-19.json)
records the upstream manifest commit and digest. The newer 3.12 security releases
in that manifest have Linux builds; 3.12.10 provides the Windows/macOS binaries.
The per-platform policy makes this existing difference explicit instead of
requesting an unavailable binary. It is not a claim of identical patches across
OSes. Java/.NET pins are the versions observed in successful prior platform jobs.

`native-inputs.json` hashes reviewed **public UTF-8 source**, normalizing CRLF to
LF for Windows checkout. It detects changes to the wrapper/plugin/SDK recipes and
existing binary digests. It is not a hash of every installed OS/compiler binary.
Xcode, MSVC/CMake and runner image patch revisions remain platform-image inputs;
runner compatibility/publication acceptance belongs to #400/#386/#396. The
self-hosted builder/macOS bootstrap interpreter is not replaced or cached here.
Hosted Python commands select/check the policy before running; a retained-release
checkout does not re-run a new module from an old source revision. Deploy's
read-only route permits only the exact reviewed SDK bootstrap and metadata reader.

Python verification requirements keep their exact direct releases. Their
transitive resolver output is not newly claimed as a complete hashed environment;
no pip cache or virtualenv archive is introduced. Gradle native dependency
resolution also has no new shared cache. Pub dependency trees are public locks,
not cached auth/config directories. SDK/dependency cache restoration never skips
unit tests, analysis, packaging, signatures or actual acceptance.

## Local reproduction

Install the reviewed platform SDKs, then use the existing Taskfile commands. For
the auxiliary checks, invoke the intended interpreter explicitly when a developer
has multiple Python installations:

```sh
python -m venv .out/ci-venv
# Activate it using the shell's normal platform-specific activation command.
python -m pip install -r tools/requirements-ci.txt
python -m tools.verify.toolchains.check
python -m tools.ci.toolchains.runtime python
python -m tools.ci.toolchains.runtime java     # Android target
python -m tools.ci.toolchains.runtime dotnet   # Windows package target
python -m tools.ci.native.flutter
```

Updating a vendor dependency requires resolving that package's lock with the
approved Flutter, reviewing public URLs/package SHA256s, copying the lock into
`tools/ci/flutter_setup/locks/`, and updating its pubspec/lock digests. Never commit
Pub credentials, `.dart_tool`, downloaded packages, local.properties or SDK trees.
Updating a native recipe requires reviewing/updating `native-inputs.json` too.

## Hosted cache measurement

[Dependency cache acceptance](../../.github/workflows/dependency-cache-acceptance.yaml)
is read-only, hosted and has no secrets/publishing/environment access. It runs on
changes to its measurement/policy inputs or an explicit dispatch. Linux measures
two independent empty-cache/warm-cache pairs for npm installs and the same pure
Go package. macOS verifies availability of its selected Python binary; Windows
Python/.NET and Linux Java are exercised in the existing full platform gates.

```sh
python -m unittest tools.ci.toolchains.test_auxiliary tools.ci.flutter_setup.test_vendor_locks tools.ci.cache_measure.test_results
python -m tools.ci.cache_measure.run
```

The benchmark requires a clean source checkout and the approved Node/Go SDKs.
Every npm observation recreates node_modules with `npm ci` in a bounded public
fixture and executes four unchanged stats/attempt application assertions using
the installed Vitest. Both vendor regression suites/full app tests remain in CI;
this fixture is not a replacement. Every Go observation uses `-count=1 -json` and
requires the same seven tests without skip/fail/cached test results. Each cold
pair starts with new private directories; only its matching warm observation
reuses public npm contents or Go module/compiled-object cache. No auth/config/DB
or test-result cache is retained. Temporary dirs are deleted after the job.

The sanitized artifact binds source SHA, public input hashes, actual SDKs,
platform/arch, all four test lists/timings and descriptive nearest-rank p50/p95
with **n=2** per temperature. Missing/failed/skipped/duplicate/incomparable
observations fail. This establishes scoped install/build-cache behavior; it does
not establish full CI latency, cross-platform performance or media capacity.
The core CI never depends on a cache hit or accepts this benchmark as a release
receipt. Replay actual acceptance artifacts through their existing documented
validators; mandatory release receipts/bundles and retention are unchanged.


## Owned rollback dependency startup

An isolated diagnostic observed the retained SFU refusing RoomService TCP
connections during setup. QA now waits at most 60 seconds **only** for the exact
canonical `roomservice ConnectionRefusedError` startup result. Auth/ACL, DNS,
endpoint, unknown failures and command exceptions fail immediately; a real
successful authenticated canonical probe remains required. The accepted QA
artifact records attempts/elapsed/refusals. Browser/assertion, signature, health
and canonical install/rollback criteria are unchanged. This is owned disposable
fixture setup, not a production health retry or a media capacity claim.
