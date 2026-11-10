# Issue 689: isolated public WebSocket transport

- PASS: Go WebSocket tests, ten repetitions, and five after test fixture split: ready, initial snapshot, changed state, unavailable source, foreign Origin, query rejection, absent native Origin, handshake rate and twenty-connection quota.
- PASS: Linux Go race detector, three repetitions; `go vet` and specification traceability.
- NOT RUN: registered runtime route, real proxy, browser/Android and deployed-stack/load. The handler is not wired into the app and this is not release acceptance.
