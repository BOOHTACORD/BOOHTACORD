# PR 695: recovery after WebSocket migration

Issue 689 replaced the roster SSE connection with the shared realtime socket.
The obsolete SSE retry code and its removed-controller tests are not restored.
The adapted regression drives nine failed socket opens with virtual time,
checks that only one retry remains scheduled, then observes protocol-ready.
The existing roster event and transfer-revocation tests remain part of scope.

On the local Windows host, 14 focused Flutter tests and 20 LiveKit network
verifier tests passed on the reconciled working tree. The full feature gate
and actual native media path have not been shown to pass on this source.
Physical Android, iOS, production and audible-media acceptance remain NOT_RUN.
