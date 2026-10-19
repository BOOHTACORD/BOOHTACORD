# CICD-11 / #395 delivery foundation

Status: implementation in progress; no runtime acceptance or closed delivery gate.

Before implementation, five focused test methods reproduced six failing assertions
while the existing-writer lock control passed. On baseline master `8547b88e`,
automatic read-only routing inherited the workflow-level production writer group.
GitHub's default single pending slot can replace an older pending run even when
the active run is not canceled. Therefore a no-bundle completion can interfere
with a queued release. A separate control confirms all three current production
writers still hold the shared non-cancellable lock. New tests preserve that control
and require the policy to reject a read-only job entering the writer queue.

The local candidate moves the automatic writer lock to the `install` job. Neither
the automatic workflow nor its read-only route holds a concurrency group. Manual
retained install and compatible rollback keep their existing workflow-level lock;
all three writers retain the same group and `cancel-in-progress: false`. Policy
tests reject an unlocked/cancellable installer, another unprotected writer and a
reader acquiring the production group. Source, environment, signature, producer
and rollback controls are unchanged by this first step.

Validation: 14 nearby tests PASS, full 835 Python tests PASS in 42.991 seconds,
Actionlint 1.7.11 PASS, full workflow policy PASS (30 workflows / one local action),
spec traceability PASS_INDEX_ONLY39 (approved brief unavailable). These are local
software/policy results. Actual mixed workflow/job lock contention and the rest
of CICD-11 runtime acceptance remain NOT_RUN. This candidate is not yet published.

Primary semantics: [GitHub concurrency documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency).
The currently pinned Actionlint 1.7.11 rejects the newly documented `queue: max`;
an actual local parser probe reproduced that error. No unsupported syntax,
lint bypass, queue mutation or concurrent production experiment was introduced.
The default one-pending behavior for qualified production writers remains; this
first fix does not promise FIFO or preservation of every pending release.

Remaining scope: common trusted auto/manual installation, source-bound phase
timeouts and sanitized receipts/readback, negative SSH/health cases, consecutive
real releases and approved compatible rollback in an explicit production or owned
isolated real-stack scope. Keep checksum/signature/history/volume/ACL/maintenance
guards. Do not treat HTTP liveness or a transport cancellation as installed-source
proof; do not rerun production blindly or initiate rollback without approval.

Authenticated read-only Settings audit found master-only environment restriction
but no required human reviewer. Owner-managed #385 and external #386 acceptance
remain separate and open. No credential or settings changes are part of this record.
