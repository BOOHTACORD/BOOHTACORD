# Issue 689: roster observation fence

- PASS: 20 native test runs, five Linux race runs, Go vet and specification traceability. An invalidated, closed or different-account observation is rejected; a fresh observation is accepted.
- NOT RUN: guarded WebSocket writes and concurrent revocation between the final check and network delivery. The in-memory fence is not an ACL/session check and is not an atomic network-write guarantee.
