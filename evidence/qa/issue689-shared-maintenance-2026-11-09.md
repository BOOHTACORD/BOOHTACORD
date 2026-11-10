# Issue 689: shared maintenance wiring

- PASS: actual public and authenticated test WebSockets share the same observer generation and revision and receive the same transition; three runs with Linux race detector. App route composition and OpenAPI/traceability checks pass.
- NOT RUN: the combined path on the rebuilt deployed stack, actual CLI, browser/Android clients, load and revocation under slow writers. Clients do not yet negotiate this capability in production; SSE is still active.
