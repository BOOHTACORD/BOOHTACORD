# Issue 689: public route integration

- PASS: Linux app composition test uses an actual WebSocket through the HTTP middleware; race detector passed. Windows backend command build and Go vet passed. OpenAPI parity: 137 public operations; contract tests and spec traceability passed.
- PASS: isolated PostgreSQL schema test changes maintenance through an independent SQL update and observes `maintenance.changed` on a real socket at the next five-second check. This verifies external database changes, not the maintenance CLI itself.
- PASS (preliminary): locally owned Docker/PostgreSQL/Caddy stand, TLS proxy handshake and ready/maintenance snapshot with only public fields. The image was built from `d6824a0d9` plus then-uncommitted route integration; it is not an immutable release candidate, and this smoke does not prove load or completed migration.
- NOT RUN: CLI change, authenticated maintenance delivery, final candidate, fault/load matrix and all required client/platform acceptance. Legacy SSE remains active during migration.
