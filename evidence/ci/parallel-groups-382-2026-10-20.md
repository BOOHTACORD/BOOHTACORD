# Issue #382: split existing long checks only

Base: master `19aff0d6e0004a342b09bbacacd09887a74934dd`.

Web retains its immutable baseline and all 40 operations exactly once. The existing
browser matrix adds `browser-content`; the shell profile keeps accessibility,
responsive shell and controls, while content runs microcopy, chat rhythm, message
social and navigation. Both retain the existing source-bound parts and capture
packaging. The fan-in requires all six profiles.

Android keeps the two-mode Kotlin script unchanged, running it in `android-kotlin`
independently of the inspected debug APK in `android`. Dart remains independent;
the same pinned Flutter/Dart/Java selections and exact source apply. All three
parts are mandatory. Failed, skipped, cancelled, foreign or incomplete parts fail.

Windows is unchanged: native master run 39428374813 measured native-unit 749s,
while build 386s + GUI/SFU 417s = 803s (806s including the inter-job wait).
Splitting native-unit is not supported by this sample's critical path.

Focused regression: 149 tests PASS, including command inventory, workflow guards,
artifact publication, stale/foreign/missing results and fan-in rejection. Tests
were first run against the original implementation: four failures and two errors
confirmed the missing split and missing mandatory profile.

The complete tools Python regression also passed: 1,136 tests. Contract verification
passed (19 focused parity tests, OpenAPI lint and 113-operation parity); actionlint
passed for both changed workflows.

Hosted split timing and actual APK/browser execution: NOT_RUN before PR CI.
Compare the existing 40-operation Web and two-mode Kotlin + APK coverage with this
base; report actual job intervals, distinct runners and whole-gate elapsed time.
No speed claim or closure follows from local mocks alone. No new comparison or
release workflow is introduced; existing manual comparison readers accept the
expanded set of mandatory profiles.
