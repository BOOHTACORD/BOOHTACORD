# Issue 689: socket-scoped roster preparation

- PASS: focused tests bind a coordinator subscription and guard to the supplied account and session, reject quota/invalid account, and prove that closing cancels an in-flight context-aware guard and stops its stream. Repeated Go tests, Go vet, ten Linux race-detector repetitions and spec traceability passed.
- NOT RUN: application composition, actual PostgreSQL/LiveKit through this adapter, write-boundary revocation, client migration and load. The guard must honor cancellation; this isolated packet does not enable roster delivery in the application.
