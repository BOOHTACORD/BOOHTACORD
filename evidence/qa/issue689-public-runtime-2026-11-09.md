# Issue 689: public realtime lifecycle

- PASS: Go tests, ten repetitions; 20 real test WebSockets share authoritative reads and close after observer shutdown. Invalid origin and trusted-proxy configuration fail startup.
- PASS: explicit inbound frame bound and rejection of client commands; Linux race detector three repetitions and spec traceability.
- NOT RUN: route integration, real PostgreSQL/CLI lifecycle, metrics, proxy and comparative load. Admission budgets are initial safeguards, not measured capacity.
