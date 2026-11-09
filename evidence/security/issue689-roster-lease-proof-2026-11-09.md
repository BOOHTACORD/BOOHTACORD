# Issue 689: internal matched lease proof

- PASS: real PostgreSQL fixture and all `list_connected_participants` packages without skips; Linux race detector on service tests; normalization/coordinator regressions and spec traceability.
- PASS: the exact matched lease survives roster normalization but is excluded from HTTP/WS JSON. Existing service tests and the wire shape remain intact; their oversized fixture was split without changing behavior.
- NOT RUN: outbound reauthorization and revocation during write. The proof is not an authorization check and must not be exposed to a client or log.
