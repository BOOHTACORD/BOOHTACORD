# Issue 689: Flutter maintenance payload validation

Status: **PASS_SCOPED** for targeted tests and analysis. Server delivery and runtime acceptance remain **NOT_RUN**.

- A focused test first showed that malformed maintenance state left the client connected. The new check rejects malformed state, resets the durable cursor and uses the existing close/retry path. Valid snapshots and changes are delivered without advancing that cursor.
- Tests cover missing/non-object payload, extra fields, invalid version, generation, revision and active value for both event kinds. A separate RED/GREEN case preserves JSON Schema parity for integer-valued JSON numbers such as `1.0`.
- The full `test/realtime_scope` directory passed **22 tests**; focused Flutter analysis, the direct contracts verifier and spec traceability passed.
- Validation of the complete event envelope and malformed events of other kinds remains outstanding. No live maintenance event, guest/auth handoff, Android/iOS/macOS device result or release acceptance is inferred here.
