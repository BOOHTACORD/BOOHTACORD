# Issue 689: asynchronous final roster check

**Route:** authenticated socket writer and bounded roster authorization pool.

- [x] Reproduce a queued prepared snapshot whose recipient session becomes invalid before the writer is ready; keep other socket events flowing while the final check is slow.
- [x] Recheck session, visibility and leases asynchronously when the writer can send; discard/recheck proof after intervening writes and honor coordinator invalidation.
- [x] Exercise revocation, stale ACL, outage and event-priority cases with race tests and the real PostgreSQL fixture. True write/revocation atomicity and full-stack fault/load acceptance remain separate.
