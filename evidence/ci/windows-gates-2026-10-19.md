# #391 — Windows gate implementation

The native unit/build/GUI DAG now has one CI package build, separate runner
filesystems and a mandatory stable aggregate. Full payload transfer verifies
source/run/attempt, manifest, complete inventories, checksums, contracts,
toolchains, native build identity, installer files and explicit QA purpose.
Recovery and the real GUI driver execute the same retained native bytes.

The CI package uses a QA entrypoint containing test instrumentation. Its default
branch calls production main for recovery; its explicitly enabled hosted-only
branch runs the existing real GUI/SFU fixture. It is marked stable_release:false
and is not published as a stable client. Ordinary release builds stay separate.
No claim is made that the CI package is a published stable binary.

Focused TDD initially failed with missing transfer and workflow modules. Negative
cases now cover source/dirty/tampered/missing/added/linked/foreign files, checksums,
installer payload, manifest, retry, skipped GUI, rebuild, optional native tests,
failed recovery/GUI and changed post-run payload. Existing native artifact,
Windows packaging/plugin/runtime, GUI result and Actions trust regressions are
included. Dart QA entrypoint: formatter unchanged; analyzer **PASS, no issues**.

New full Windows hosted build, actual recovery/GUI execution and repeated
p50/p95/failure-rate measurements: **NOT_RUN** here. The owner requested focused
basic checks and implementation before repeated long native acceptance runs.
The issue remains open for that combined acceptance.

Final focused result: **35 PASS in 1.557 s**. Workflow policy: **PASS** (31
workflows, 2 local actions), Actionlint 1.7.11: **PASS**, diff whitespace: **PASS**.
Required traceability: **PASS_INDEX_ONLY**, 39 requirements; approved external
brief unavailable on this host. No local VM or repeated whole-suite run used.
