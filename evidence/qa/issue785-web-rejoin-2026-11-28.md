# Issue 785: early Web signaling recovery

Status: **PASS_SCOPED** for the registered desktop/responsive Web repair;
hosted delivery is pending. `gate_closed: false`. Base master:
`536f39c5dbede4e8b73f43178d80c468119b3b01`. No physical/native acceptance is claimed.

## Reproduction and cause

The earlier historical failure had no retained server cause. This investigation
reproduced the same Web rejoin symptom on unchanged master production code,
including a normal WebSocket without the subscription interceptor. Admission
returned 201/200; the SFU handshake returned HTTP 500 before ICE, with server
error `could not find any available nodes`. The client stayed in ERROR.

A later post-SFU-pause witness had the same SDK message and WebSocket reason 6.
An immediate private registry read found one SERVING node with statistics age
0 s, CPU load 0.015773272 on two CPUs, 75 ms after the failed handshake. This
shows a transient allocation failure, not proof of CPU overload or capacity.
The exact external trigger of the first historical episode remains unproven.

LiveKit 1.13.7 rejects a stale node at a five-second statistics age and normally
updates statistics every two seconds; existing media can remain active while a
new admission cannot select a node. Sources: [selector](https://github.com/livekit/livekit/blob/v1.13.7/pkg/routing/selector/utils.go),
[allocator](https://github.com/livekit/livekit/blob/v1.13.7/pkg/service/roomallocator.go),
[configuration](https://github.com/livekit/livekit/blob/v1.13.7/pkg/config/config.go).
The original client reconnect monitor only handles already admitted sessions.

## Repair and preservation

- Replace a failed early WebSocket Room once after 2 s, within the original
  20 s connect budget. Destroy the failed Room first; do not retry capture,
  device changes, authorization failures, cancellation, timeouts or unknown errors.
- Keep the exact lease and ask the server for its credential again. A denied
  lease stops recovery; a new microphone restriction remains listener-only.
- Generation and exact pending revocation fence retries and publication after
  leave/logout. No new lease or force transfer is introduced.
- Split the existing oversized session facade and test fixtures by ownership;
  preserve all 13 session and six transfer tests. Flutter production is unchanged.

## Before/after and native checks

Owned WSL2 x86_64 Go/PostgreSQL/LiveKit/Redis/Egress fixture, pinned SDK 2.22.3,
Playwright 1.63.0/Chromium 153. Synthetic publisher and independent receiver;
no production mutation. Ordinary SFU health thresholds and CPU limits remain.

The registered logout/login path now uses the same document and preserves every
old media-detach/peer-close assertion. A guarded fault removes only the owned
SFU discovery entry just after a heartbeat. Its ordinary heartbeat restores it;
the test requires an actual handshake 500, one lease, two credential checks on
that same lease, and recovered decoded video. Safety tests reject foreign
services, multiple/missing nodes, absent heartbeats and an unapplied fault.

- Controlled BEFORE: master production unchanged; verified gap, one handshake
  500, one lease, one credential, setup_failed=false; original 30 s assertion FAIL.
- Controlled AFTER: automatic recovery PASS; one 201 lease, two 200 credential
  checks, identical lease path, heartbeat restored discovery. Full controller PASS
  and owned resources removed. This precedes the additional deadline-edge guard;
  final registered acceptance must bind the final source.
- Original preservation baseline: 26 tests PASS. Six new recovery/cancellation
  regressions failed before implementation; eight negative/preservation cases passed.
  A further deadline-edge regression failed before its guard, then passed.
- Windows full Web unit suite: 2120 PASS / zero skips before that final extra
  deadline test. Focused final deadline suite: six PASS. Production build PASS
  with VITE_PUBLIC_ORIGIN=https://localhost:4810.
- Discovery safety: ten Node cases and its Python Contracts wrapper PASS.
- Final registered eight-feature Web check: **29/29 stages PASS**, including
  2121 unit tests / zero skips, build, all browser suites, both actual-stack
  widths (1440/393) and unchanged endpoint source fingerprints.
- Native Contracts: PASS, 1894 Python tests / 28 declared platform/opt-in skips.
  Derived parity/projection, flow bindings and signal-catalog check PASS.
- Hosted exact-head CI and merge/master verification remain pending; final
  delivery results are recorded in the PR and issue, not predicted here.

Exploration retained: fresh controllers 1-3 PASS; controller 4 passed rejoin then
failed a separate roster-button race. The planned fifth was not run. Twenty
viewer/reload cycles and twenty spaced in-page cycles passed. Fast login stress
also encountered a separate 429. Native burst 1 reproduced rejoin/500; bursts
2-3 passed; burst 4 passed its eight rejoins then reproduced the same early
signaling failure after the later SFU-pause case. These exploratory hooks are
not canonical acceptance and their failures have not been relabeled PASS.

## Source binding and retained results

Runtime root: `/root/.cache/boohtacord-785-rejoin-20261128/.out`.
`controlled-before/`, `controlled-after/`, `reproduction-*`, `viewer-stress/`,
`inpage-stress/`, `service-logs-stress/`, `spaced-inpage-r1/`, `proxy-burst-r1/`,
and `native-burst-r*` retain the individual outcomes. Server receipts contain
only fixed operational messages/status/error fields; credentials, request
headers, URLs, identities, SDP and media payloads are not retained.

Registered receipt: `.out/local-features/20261128-130837/report.json`; SHA256
`f28867418dccfc8666445b19c8926884c0e768b5d814b5bc915442f32ea93411`.
Runtime source: `536f39c5dbede4e8b73f43178d80c468119b3b01 worktree-sha256=ade8b78d07834a62bb1b06920b8a3d4f7b161ff957d4f3fea643eb620687b644`.
All 35 changed runtime/test/registry files match Windows and Linux after
UTF-8/LF normalization. Sorted compact JSON rows `{path,sha256_lf,lines}`
bundle SHA256: `85a8a406a8e7a287a843ffec51c5ba0b38afd917e8b782ec746a98ed830816d2`.
Final captures `.out/client-lifecycle/<width>/web-rejoin-recovered.png`:
- 1440: `106cc4b724d1c6e54f7c9f1055e9dfa60167c2c2788d51e9d4c2b9609012e6cd`.
- 393: `6f7680ba34d0493cb90f0d335e8e8ede1be23c5bec46f594fcbaae6fec66f819`.
Both source-sized captures were reviewed: connected dock, recovered decoded
stream and accessible controls; no error banner or overlapping controls.
The full unrelated gallery remains visual_review=NOT_RUN/REVIEW_REQUIRED.
No baseline was approved. Failed exploratory/setup runs remain retained.
Physical 60-minute audibility, mobile OS lifecycle/Doze, iOS and installed
release acceptance remain open in #785. This Web repair does not close them.
