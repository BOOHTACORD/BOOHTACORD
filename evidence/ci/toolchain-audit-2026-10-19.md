# Auxiliary SDK and dependency-cache acceptance — 19 October 2026

Follow-up for #392, based on master `bdbbeeb617b2ee74fc5fe3d021d81c4ce91fdb67`.
Prior #420 cache namespace/SDK identity changes and the local npm/Go observations
remain historical evidence in their stated scope.

New focused tests failed before implementation (missing audit/result/vendor
modules). The complete local Python suite initially caught the deploy reader's
strict two-step allowlist; it was updated to permit exactly the read-only pinned
Python bootstrap/runtime check and original metadata reader. Added negative tests
reject extra commands, loose SDKs, skipped identity checks or credentials. No
production environment, publisher scope, queue or provenance check was relaxed.

Local final checks: **627 Python tests PASS** (38.800 s); source-pinned actionlint,
Actions trust/pins, workflow contracts, documentation links and exact native input
audit PASS. Traceability is **PASS_INDEX_ONLY**, 39 requirements; the approved
Windows brief is unavailable on this host. No wire/API contract changes.

The actual npm fixture installed the committed dependency tree and executed all
four unchanged stats/attempt assertions; strict Vitest JSON parsing PASS. This is
a fixture integration smoke, not a hosted cold/warm result. Both standalone vendor
locks resolved with `flutter pub get --enforce-lockfile` from a new empty Pub cache
using Flutter 3.47.7/Dart 3.13.5; the installed locks stayed byte-identical. App
pubspec/lock/runtime code is unchanged. The full original app/vendor regression,
Kotlin/APK, Windows packaging/recovery/GUI and Web/backend gates remain mandatory.

[Official availability/observed versions](auxiliary-sdk-availability-2026-10-19.json)
records the immutable upstream Python manifest/digest, prior successful Java/.NET
job sources and official Gradle checksum. The [audit/runbook](../../docs/ci/auxiliary-toolchains.md)
records exact selected versus platform-image-provided inputs and cache decisions.
No pip, Gradle, browser or native binary cache is added without measurement.
Vendor locks are public reviewed dependency inputs, not credentials/downloaded code.

Hosted cold/warm observations and exact-source full platform CI are **PENDING** at
this checkpoint. The new read-only workflow must execute two independent cold/warm
pairs each for npm/Go, retain a SHA-bound public report and reject missing, skipped,
failed, duplicate or changed assertion sets. The macOS Python binary must actually
install; Linux Java/Python and Windows .NET/Python must pass the existing platform
gates. No full CI p50/p95, native publication, media capacity or repository-settings
acceptance is inferred from a microbenchmark. Complete #392 only after the hosted
results and merge source are verified; #386/#382 retain their separate remaining
acceptance requirements.


Initial hosted head `5209702d` / checkout `0d0de0b2` **FAIL** at the new Java runtime
assertion (Flutter job 117903902061, CI 39204358616). The setup action's cached
label is 17.0.20+1, while the actual Eclipse Adoptium runtime property is
17.0.20.1+1. The isolated read-only public-property probe
[39204506116 / 117904298991](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39204506116/job/117904298991)
confirms this exact value without publishing the rest of Java properties or user
environment. The policy now pins the selection label and complete runtime value
separately; no prefix/major-only comparison or ignored mismatch. The observed
value failed a focused test before correction and passes after. Prior failed CI
is retained as FAIL; a fresh complete source-bound CI is required. The diagnostic
branch's added probe omitted Python setup and its separate contracts run correctly
rejected it; that temporary workflow is excluded from the product candidate.

A final fault-injection check simulates a zero-exit wrapper producing no new
Vitest report after one valid observation. Each pair/temperature now has a unique
report path; a missing current file cannot reuse a previous PASS. The test fails
before this change and passes after it. Fresh hosted measurement/CI are required
for this correction too; earlier successful observations retain their own SHA.


Head `2d25c8a1` actual Next acceptance **FAIL** in run 39205558124/job117907503773.
Bounded failure artifact 12164674751 (ZIP SHA256
`41ba41ad8d3ffe7eaf16ba602834cff4fd6d6355255655b60f74e1157a060532`)
shows the prior unread scope's saved-position context visible and the main list
hidden (zero viewport), with the navigation reply absent from the main DOM.
The original failure image was reviewed. Product code deliberately restores this
position; the sequential harness was assuming it had returned to latest.
Navigation now owns a fresh channel with the same 121 actual database rows and
adds a visible-main precondition. The earlier unread/restore assertions remain
intact in their original scope. New negative tests reject scope reuse, incomplete
or duplicate history, and failed setup. All nine original navigation assertions,
20s timeouts, 2px offset tolerance, unseen-tail/foreign-DM/voice-lease checks are
unchanged. No product code or mandatory acceptance is removed. Fresh exact-source
hosted acceptance is required; old PASS/FAIL observations retain their own SHA.


The 2d25c8a1 Flutter job117907914045 also **FAIL** after app tests when Pub recursed
into livekit_client/example with --enforce-lockfile but no committed example lock.
The earlier local cold-Pub check had an existing ignored example lock and did not
reproduce the clean-checkout condition. Standalone vendor resolution now uses
--no-example: example is already excluded from app analysis and neither original
vendor test command targets its tests/build. Both original root vendor suites and
app analysis remain mandatory; no assertions are skipped. A focused command
regression fails before/pass after. Fresh Git-extracted sources with no ignored
example lock and a new Pub cache must resolve the two exact vendor locks without
creating an example lock. Actual hosted platform acceptance remains required.


The first isolated-navigation run at head74193e87, checkout7199d8be, **FAIL** at
its later search precondition: the new scope had no initial read cursor, while
the original preceding unread scenario had established one. Failure artifact
12166106878 (SHA256`20d423b89b1a2d2d373551c9b39725c4e2fda08dfb70f3c2c74596b4259f2b90`)
shows visible main history/reply and no saved context; the failure image was
reviewed. The isolated scope now recreates that original baseline through the
actual authenticated read-cursor API and checks it in PostgreSQL, **before** the
unseen-tail rows are added. New tests reject missing/incorrect/failed baseline
setup. The later genuinely unseen-row/cursor invariant is unchanged, not removed.
