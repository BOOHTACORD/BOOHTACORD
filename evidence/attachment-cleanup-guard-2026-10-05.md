# Attachment cleanup guard and read-only inspection

Status: PASS for PostgreSQL/filesystem integration. Date: 2026-10-05. Issue: #90.
Source merge: `7242d73dbbf4449f76be206c6fb7e9691e64b333`.
[Native backend run](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37360553088),
backend job `111934208226`: 1033 passed, 0 skipped, 0 failed; vet/build passed.
Executor: GitHub Ubuntu 24.04 with disposable PostgreSQL 17.6.

Observed actual PostgreSQL checks:

- Full migrations accept the fixture; UNATTACHED/DELETING timestamps and retry state
  satisfy the native constraints. Early invalid fixtures were corrected, not the constraints.
- Dry-run counts two eligible UNATTACHED/DELETING rows, eight metadata bytes, one fresh
  skip and an oldest due retry of at least 3599 seconds; one HIDDEN row is eligible.
- Attachment row checksum, audit count and cleanup claim sequence remain unchanged.
- A live TEXT/DM link arriving after claim prevents the filesystem callback.
- A second connection cannot acquire FOR UPDATE NOWAIT during that callback (55P03).
- Retry, repeat, missing-file handling and claim fairness regressions pass.
- The native staging CLI executes --dry-run against actual temporary files without unlinking.
- Bounded staging batches and repeat execution preserve unselected files.

Production PostgreSQL adapters recheck state, token/key and live links under a row lock
before unlinking, and hold it through metadata finalization. Foreign key locks protect
against newly attached links. A database failure after unlink remains retryable; missing
files are idempotent. Published history has no TTL.
Reports contain aggregate metadata bytes and bounded skip reasons, never names or keys.
Metadata bytes are not a measured promise of reclaimed physical storage.
[Operator instructions](../docs/runbooks/attachment-cleanup.md).
This receipt uses disposable data; it does not claim production free-space recovery.
