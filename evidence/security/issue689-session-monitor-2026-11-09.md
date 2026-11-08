# Issue 689: session monitoring under blocked writes

- PASS: the monitor checks a revoked session while a synthetic 16 MiB frame blocks the writer; the handler closes in about 5.1 s in this focused test. Account/session mismatch closes with policy status, and a session-store error closes with retry status instead of asserting revocation.
- PASS: full connect-session package against the local PostgreSQL stand in disposable isolated schemas, without skipped tests; Go vet, Linux race detector (three focused repetitions), and spec traceability.
- The monitor caps its interval at 1.5 s and its database lookup at 1 s; the WebSocket library's close handshake has a 5 s deadline. These timeouts rely on the authenticator honoring context cancellation and do not establish a hard scheduling guarantee under overload. The increased lookup rate needs measurement in the full load matrix.
- NOT RUN: concurrent revocation at every write boundary, degraded PostgreSQL load, realistic slow-client capacity, and final end-to-end release acceptance. Private-event and replay paths have separate authorization checks and require the same outage/error audit before cutover.
