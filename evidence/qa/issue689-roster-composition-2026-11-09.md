# Issue 689: application roster composition

- PASS: a real in-process WebSocket receives a roster through the shared coordinator and recipient guard; process shutdown closes the stream. Existing route registration and session/origin checks passed in Linux, alongside focused Go tests, race tests, Go vet, command build and spec traceability.
- The app uses the same PostgreSQL roster repository, LiveKit coalescing gate and notifier as existing routes; the coordinator has one five-second reconcile ticker and bounded workers. The new route capability is opt-in, while existing clients still use their former voice stream.
- NOT RUN: this composed path against real PostgreSQL and LiveKit, signed webhook end-to-end, simultaneous permission/session/lease revocation during the gap between asynchronous guard and network write, event priority, real client migration and full load. Capability availability must not be interpreted as production readiness.
