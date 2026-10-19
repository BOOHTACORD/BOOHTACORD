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
# Combined actual acceptance — 2026-10-20

The final scoped record is `windows-gates-final-2026-10-20.json`. Native run
39319882366/source3d22e900 completed all nine jobs, including one Windows build,
native unit tests, real recovery/GUI/SFU and required aggregates. Four small
evidence ZIPs were independently downloaded and API ownership/size/digest verified;
the full executable/installer is not claimed as a second local download. Transfer,
GUI and acceptance share manifest224d7b093a6a43fa57e953bbe377b477742acfc4cf0ead009e98505bfe38edf4.
Eight capture hashes passed; header-open and dock-footer originals were reviewed.
The fixed Cancel/Start footer fits, and quality controls remain reachable by scrolling.

Existing focused failure/manifest/runner-boundary checks: 9 test methods PASS in
0.120 s. Actual GUI-child cancellations in eight old-policy runs produced red
Windows aggregates, never advisory green. Complete bounded API collection retained
all13 native workflows since implementation through20:51:56UTC, including the
metadata-only run and all cancellations. Four successful relevant sources share
the current Windows gate/build recipe. Their observed execution p50/p95 is
877/1025 s versus frozen baseline13-success1520/1611 s; availability including
waits1025/1329 s versus1533/1625 s, using the shared nearest-rank definition.
Parallel occupancy increased; no cost saving, intrinsic flake rate or population
SLO is inferred. Original two baseline failures and all eight after cancellations
are retained. No new heavy run was dispatched for this evidence.
