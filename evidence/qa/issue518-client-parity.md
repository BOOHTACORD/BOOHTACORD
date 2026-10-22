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
- Web suite: PASS, 1609 tests / 483 files, including 2 bounded-delivery regressions.
- Contract verifier: PASS, 19 tests; OpenAPI 116 public / 4 private operations.
- Spec traceability: PASS, 39 indexed requirements; approved Windows brief
  unavailable on this Mac, so this is committed-index validation only.
- Android actual Go/PostgreSQL replay TEXT/edit/delete/react/pin + reachable
  telemetry: passed in `.out/issue518/android-parity2`; a refresh tap missed its
  hit target, so the strengthened scenario makes missed taps fatal and is rerun.
- Strengthened actual-stack smoke: PASS separately on Android API35 emulator
  and iOS27 QA Simulator, version 1.0.45 (80), missed taps made fatal. Both
  exercised real Go/PostgreSQL/TLS, TEXT edit/delete/react/pin replay, a second
  account DM edit replay, no duplicates, preserved selection, reachable Guild
  telemetry GET/refresh, default local-only mode and logout cursor cleanup.
  The peer fixture explicitly selects the signed-in peer instead of an unrelated
  seeded member; server correctly denied the unrelated pair during test setup.
  Android: `.out/issue518/android-parity-final`, source `5fbbc9f2`, working diff
  `511797acce4784c7f95ffea829cb0cb5b3bf5c503fa18782f51546297e8c81ab`.
  iOS: `.out/issue518/ios-parity3`, source `5fbbc9f2`, working diff
  `710d3da76aeb8e452eb9b953c0cb4eaaa500aca86be88b3db7720acd5181b4a8`.
  Generated images were inspected: ID wraps, consent stays readable, enabling
  remains disabled without consent, refresh is reachable by scrolling, and DM
  displays the peer's updated message. Screenshots are synthetic private QA data.
- Flutter analyzer: PASS with existing informational lints; no errors/warnings.
- CI action-pin/source policy: PASS (36 workflows / 2 local actions), 8 tests.
- Final registered feature smoke and exact-source release receipts: pending.
- Release candidates: 1.0.45 (80), release order 59; release receipts pending.

Physical iPhone/Android capture with/without audio, OS stop, background and
rotation, VoiceOver/TalkBack and paired physical media remain NOT_RUN, tracked
by #62/#132/#303. This report does not close those acceptance gates.
Generated screenshots, logs, secrets and artifacts remain outside Git.
