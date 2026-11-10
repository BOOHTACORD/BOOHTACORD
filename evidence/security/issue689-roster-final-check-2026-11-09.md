# Issue 689: asynchronous delivery-time authorization

- PASS: tests force a delayed final check while another socket event flows, then revoke the session; no queued roster is sent. A successful proof is repeated after an intervening write. Stale visibility requests refresh, and unavailable authorization emits only a fixed unavailable event.
- PASS: complete affected Go packages, including real PostgreSQL fixture tests in isolated schemas without skips; five focused Linux race-detector repetitions, Go vet and spec traceability.
- The final check uses the same bounded worker pool and rechecks session, current visible channels and exact lease proof. Ready hub events are processed before a successful roster proof is used. This reduces the authorization-to-write gap but cannot make a database mutation and network write atomic.
- NOT RUN: exhaustive event-priority/overflow combinations, revocation exactly across the final check/write boundary, signed webhook and LiveKit end-to-end, realistic failure/load matrix, and final client/release acceptance. Repeated checks increase database demand and must be measured.
