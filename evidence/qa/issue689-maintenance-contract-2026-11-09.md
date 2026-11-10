# Issue 689: maintenance event contract

Status: **PASS_SCOPED** for schema tests only. Transport, clients, initial-state ordering, delivery and release are **NOT_RUN**.

- Before the schema change, `python -m unittest tools.verify.realtime_schema.test_maintenance` failed because the snapshot kind was absent.
- The tests now accept the exact version/generation/revision/active shape for both kinds and reject missing or extra fields, wrong types, unsupported versions, invalid UUIDs and invalid or non-JavaScript-safe revisions.
- The project contract verifier and spec traceability verifier passed. The route list remains at 136 public operations; this packet does not add an endpoint or emit these events.
- A process generation distinguishes revisions across server restarts. Unknown state is not encoded as an inactive maintenance event; its delivery and recovery semantics remain an integration task.
