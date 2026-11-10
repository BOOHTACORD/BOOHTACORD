# Issue 689: stale recipient refresh

- PASS: 20 Go test runs, five Linux race-detector runs, Go vet and spec traceability. A recipient can discard a stale queued lease proof and receive a fresh snapshot even when the visible JSON/revision is unchanged; other recipients are not sent duplicate state.
- NOT RUN: integration with the delivery guard and serial socket writer, session revocation races, LiveKit and load.
