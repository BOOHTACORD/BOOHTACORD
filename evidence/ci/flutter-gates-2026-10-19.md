# CICD-06 / #390 local implementation checkpoint

Status: **NOT_RUN for hosted native integration, comparative timing and master acceptance**.
Parent #382 and issue #390 remain open.

Prepared independently from master `f1b19038` while #388's immutable Web candidate
and repeated hosted comparison execute. Only CI orchestration, local entrypoint
delegation and a debug-only dependency reuse option change. Product Dart, Android
Kotlin, application identity, release signing and physical-device behavior do not
change. No native signing credentials, emulator or production settings were used.

Focused tests were written before implementation. Initial profile/artifact tests
failed on missing modules and the unsupported debug-only CLI option. Later source,
aggregate, workflow and framework-revision tests failed before the corresponding
implementation. These are development red stages, not accepted runtime evidence.

The focused suite covers preserved ordered app/vendor/analyze commands and locks,
both existing Kotlin modes, debug identity defines, release plugin regeneration,
exact source/run/attempt/namespace, source mutation, stale PASS overwrite, SDK
revision drift, missing/empty/indirect captures, changed APK digests, invalid
source/signing metadata, failed/cancelled/skipped children, incomplete operations,
missing/optional uploads, foreign artifact patterns and the unchanged shared
change-selection matrix. Real `flutter test`, Gradle, APK inspection, capture
review and p50/p95/runner-minute comparisons remain pending.

The final full local Python suite passed **659 tests in 39.525 seconds**. The
focused suite passes **26 tests** after source/SDK/routing guards. The existing
vendor-lock regression now patches the shared execution boundary and still calls
the original local entrypoint, preserving both vendor pub/test assertions.
Actionlint and the full PowerShell workflow policy both accepted the split.
Hosted records must still be added for the actual committed candidate.
Traceability references all 39 indexed requirements;
the approved Windows source brief is unavailable on this Mac, so this is
**PASS_INDEX_ONLY**, not full product-source validation. No wire contract changed.

The PowerShell workflow verifier initially rejected the old monolithic command
expectation after execution moved into the profiles. Its checks now
require both profiles and the aggregate; the Python native workflow policy
rejects optional commands, children, artifacts and stale artifact selection.
