# SDK and dependency cache contract (#392)

The central product versions remain in `tools/toolchains.json`, `.node-version`
and `backend/go.mod`. Before an SDK cache is restored, the standard-library-only
`python3 -m tools.ci.toolchains.cache_inputs go` (or `npm`) command validates these
inputs and writes `.out/ci/cache-inputs/<kind>.json`. Use `python` on Windows.
The generated public manifest contains the selected SDK, schema version, OS,
architecture and hashes of the explicit module/lock inputs. It contains no
configuration, environment variables, credentials or test output. The setup
Actions hash this manifest as their `cache-dependency-path`.

All eight Go setup steps select **1.26.4** explicitly. `go-version-file` alone
selected the module minimum 1.26.0 before Go automatically downloaded its declared
1.26.4 toolchain; this could key the cache for the wrong SDK. The three Windows
Go setup steps now also specify the dependency manifest. Existing backend test
commands retain `-count=1`; restoring build/download caches never replaces test
execution. All four `npm ci` workflows use the Node-versioned manifest. They
always install the lockfile and run the same checks, regardless of cache hits.

## Flutter

Every Flutter workflow uses `./.github/actions/flutter-setup`. It checks out only
installer commit `1a449444c387b1966244ae4d4f8c696479add0b2`, checks its clean Git
identity, and executes the canonical `setup.sh` Git blob. It does **not** execute
that repository's composite, whose nested `actions/cache@v5` remains mutable even
when the outer action is pinned. No upstream installer source is copied here.
The repository-owned composite pins cache restore/save by full reviewed commit.
Windows sparse checkout includes the local action. Canonical blob execution also
avoids relying on Windows checkout line-ending conversion.

The SDK cache key includes schema, OS, architecture, Flutter 3.47.7 and full
framework revision `abaf9c523780a608bd46686fd5e53740a07077f8`. The installer uses
only its managed directory beneath `RUNNER_TOOL_CACHE`. Cache restore never skips
checking actual Flutter, Dart 3.13.5 and the full framework revision. A different
cached identity fails. Only the public SDK is cached. Each job receives a new
`PUB_CACHE` beneath `RUNNER_TEMP`; user-level Pub credentials/dependencies and
self-hosted home directories are not archived. App lockfile enforcement remains
`flutter pub get --enforce-lockfile` and the native test/build commands are unchanged.

SDK cache writes require the upstream repository, a `push` event and master ref.
PR/fork/tag/manual jobs only restore SDK caches. Go/npm setup Actions retain their
existing post-save behavior: PR writes are scoped by GitHub to that PR merge ref,
which master cannot restore. This is **not** a claim that those Actions never
write any PR-local cache. The shared default-branch scope remains read-only to
PRs. See [GitHub cache isolation](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching#restrictions-for-accessing-a-cache).
No write-capable `cache-mode` override or `pull_request_target` trigger is added.

## Reproduce locally

Use the existing Taskfile setup and approved SDKs. The manifest commands above
need only Python 3.9+; the YAML policies additionally need the pinned
`tools/requirements-ci.txt` dependencies. The local composite itself is intended
for GitHub runner environment files, not a developer home installation.

```sh
python3 -m tools.ci.toolchains.cache_inputs go
python3 -m tools.ci.toolchains.cache_inputs npm
python3 -m unittest tools.ci.toolchains.test_cache_inputs tools.ci.toolchains.test_workflows
python3 -m unittest tools.ci.flutter_setup.test_metadata tools.ci.flutter_setup.test_run tools.ci.flutter_setup.test_workflow
python3 -m tools.ci.toolchains.workflows
python3 -m tools.verify.action_pins.run
```

## Measurements and remaining acceptance

[evidence/ci/dependency-cache-local-2026-10-19.json](../../evidence/ci/dependency-cache-local-2026-10-19.json)
records two local cold/warm npm install pairs using exactly the same lockfile,
Node 24.18.0 and two focused test files. `node_modules` was recreated by `npm ci`
each time. Cold installs took 9.362/12.934 seconds and warm installs 1.488/1.624;
all four test executions passed. [The Go microbenchmark](../../evidence/ci/go-cache-local-2026-10-19.json)
used the same seven package tests with `-count=1`: cold 40.879/45.927 seconds,
warm 1.164/1.183 seconds, with real test names checked for equality and no skips.
These are small local install/build measurements,
not full-suite coverage, cross-platform evidence or a CI latency SLO.

Playwright browser caching is intentionally absent: [upstream guidance](https://playwright.dev/docs/ci#caching-browsers)
notes similar restore/download costs and uncached OS dependencies. Installation
remains version-selected by package-lock and always uses `--with-deps chromium`.
No Gradle, browser, native binary or signing-result cache is introduced without
measurement. Existing native SDK downloads retain their pinned identity checks.

#392 remains open for hosted cold/warm measurements and full Java, .NET, Python,
Velopack and native SDK declaration audit. Java's current 17 family, .NET's 8.0.x
family and Python's per-platform available patches are not newly claimed as exact
pinned toolchains. #386 likewise needs independent native publication and external
GitHub settings/runner evidence. Local checks and earlier exact-source receipts
cannot attest this new composite on Windows/Linux or another merge SHA.
