# Issue 687: native Auto research selector

Status: PARTIAL. A debug-only, Windows-only compile-time research selector
can route Auto to RNNoise or DeepFilter. Release builds and non-Windows
clients select browser suppression. This selector is explicit, not a model
identity or performance preflight; the ordinary release remains unchanged.

The native state tracks selected and requested modes separately. Tests verify
the selected engine is not replaced with browser before microphone capture,
does not become active without processed frames, and is monitored for failure.
The existing capture and settings tests cover muted DeepFilter initialization,
failed model and input-switch fallback. The debug selector was tested with
each Dart compile-time define using faked native invocations; neither define
was exercised in an actual Windows UI, production capture, or release binary.

Focused Flutter tests and targeted static analysis passed. Device switching,
reconnect, physical speech, both research models through this Auto path,
runtime costs and signed release delivery remain NOT_RUN. RNNoise v0.2 weight
redistribution remains unresolved. No production release or deployment.
