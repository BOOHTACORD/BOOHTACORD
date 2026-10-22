# #518 — shared-client parity implementation and release

Task PAR-001; dependencies RP-010, IT-001, SP-001. Base master
`d537e067f7b2278e230e8488c72fb44a19379eb6`.

Implementation: awaited durable delivery with server cursor after successful
application, bounded FIFO/dedup and controlled resync on errors/overflow;
server/auth-scoped memory cursor, ready-only retry reset, jitter and manual UI
retry; scoped/coalesced audience invalidation preserving lease heartbeat and
polling fallback; existing-admin telemetry GET/PATCH panel with consent/HTTPS;
separate fullscreen exit vs stop viewing and existing renderer handoff; current
iOS app-only/broadcast documentation. Support #516 and #499–502 are reused.

The authoritative scenario matrix is the existing feature registry. CI validates
IDs, implementation/test paths and Web/iOS/Android decisions. Runtime PASS
requires separate build/source evidence. No physical media PASS is inferred
from source, component tests or an emulator/simulator.

Verification in progress:

- Initial focused tests failed on missing delivery and telemetry classes (RED).
- Full Flutter tests: PASS, 1586 tests / 1 existing skip before final additions.
- Focused delivery/retry/audience/viewer/telemetry: PASS, 23 tests.
- Web bounded delivery regression: PASS, 2 tests.
- Contract verifier: PASS, 19 tests; OpenAPI 116 public / 4 private operations.
- Spec traceability: PASS, 39 indexed requirements; approved Windows brief
  unavailable on this Mac, so this is committed-index validation only.
- Android actual Go/PostgreSQL replay TEXT/edit/delete/react/pin + reachable
  telemetry: passed in `.out/issue518/android-parity2`; a refresh tap missed its
  hit target, so the strengthened scenario makes missed taps fatal and is rerun.
- iOS actual-stack smoke / final Android strengthened smoke: RUNNING.
- Release candidates: 1.0.45 (80), release order 59; release receipts pending.

Physical iPhone/Android capture with/without audio, OS stop, background and
rotation, VoiceOver/TalkBack and paired physical media remain NOT_RUN, tracked
by #62/#132/#303. This report does not close those acceptance gates.
Generated screenshots, logs, secrets and artifacts remain outside Git.
