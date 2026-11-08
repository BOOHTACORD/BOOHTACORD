# Issue 689: Web maintenance event parsing

Status: **PASS_SCOPED** for the parser and Web unit/build checks. WebSocket delivery, guest/auth handoff and browser real-stack acceptance are **NOT_RUN**.

- The two new parser tests failed before implementation because the maintenance kinds were not recognized. They now accept the exact typed payload and reject extra, missing, malformed and out-of-range values.
- A focused realtime run passed 15 tests, including that maintenance events do not advance the durable replay cursor. The full Web unit run passed **522 files / 1802 tests**.
- `npm run build` first failed without the required `VITE_PUBLIC_ORIGIN`; it passed with the isolated value `https://localhost:4810`. The contract and spec traceability verifiers passed.
- No server emits these events in this packet, and no browser or production acceptance is inferred from parser tests.
