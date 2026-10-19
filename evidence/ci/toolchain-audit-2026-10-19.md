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
