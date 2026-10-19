# CICD-06 / #390 local implementation checkpoint

Status: **PASS** for #390 after merged PR #429 and exact-master acceptance on
`74197bec5951e672bb2daae85ab7a234ffffe545`. Parent #382 remains open.
The paragraphs below preserve development checkpoints; the final acceptance
record is `flutter-gates-final-2026-10-19.json`.

The completed same-source comparison `39229503990` has three original and three
split samples, all 13 jobs and all nine source/attempt-bound reports successful.
Recomputing against actual job metadata exactly matches the retained comparison:
critical p50 **1082 → 642 seconds**, p95 **1120 → 748 seconds**. Runner-minute
p50 is **18.033333 → 18.016667**, effectively unchanged. With n=3, p95 is the
maximum, not a general performance or billing claim.

All **16 current-head PR checks** passed. Combined release-mode proof
`39234203231` passed **722 Python tests and all 19 original negative fixtures**.
On actual master, `39237356016` has successful Dart, Android and stable Flutter
aggregate jobs. Both retained parts strictly validate the exact master SHA,
run/attempt, SDK and complete operation lists. Four downloaded ZIP digests and
sizes match GitHub metadata; actual **34 PNGs and all five Android artifact
files** match the execution reports. The APK is 159344774 bytes, SHA256
`7e52c6634151af76aba94e21fc0bc3661a1d167c3e945488f066429cbd81f236`.
The whole master CI/Windows run was still in progress at this checkpoint and
is not declared successful here. Physical device/media acceptance #62 remains
separate. The frozen record retains these scope and source distinctions.

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

The initial full local Python suite passed **659 tests in 39.525 seconds**. The
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

The measurement and capture-inventory update passes **679 local Python tests in
39.359 seconds**, plus Actionlint and the complete PowerShell workflow policy
(28 workflows and one local action). Measurement tests were red before adding
the legacy driver, phase state, strict comparator, bounded input/API reader and
manual workflow policy. They cover command/hash drift, failed control phases,
stale PASS overwrite, actual-job/source/attempt/runner inconsistencies, missing
APK/capture proof, invalid fan-in chronology and a complete `NO_GAIN` outcome.
Unit/workflow-policy reference data is hash-bound and usable without Git history;
the actual hosted legacy control independently retrieves and verifies the
original Git blobs using the required full-history checkout.

Initial hosted CI `39226238029`, PR #429 head `01f28743`, checkout `62e95c1b`,
successfully completed Dart, Android and the stable aggregate. All relevant ZIP
digests were verified. The actual APK is 159344909 bytes; its file digest,
application/debug-signing/source manifest and complete checksums match the
retained Android execution part. The UI archive contains **34 PNGs**. Original
checkout `31a13437` and new `62e95c1b` have identical Flutter application,
toolchain and framework inputs; 32 PNGs are byte-identical. Four changed Media
source files were inspected: their displayed refresh time changed from 08:32 to
08:58, with the same mobile/desktop geometry and text wrapping. Detailed public
source, artifact digests and limitations are retained in
`flutter-profile-diagnostic-2026-10-19.json`.

That inspection found a validation gap: the initial required list covered 28 of
the 34 uploaded frames. A focused failing test now requires all six existing
text/DM conversation frames too. The original uploaded review set was preserved;
the corrected inventory still requires fresh actual CI evidence. The first
diagnostic is not relabeled as final 34-part coverage or a measured speedup.
